# Public Domain (-) 2011 The Pivotal Web Authors.
# See the Pivotal Web UNLICENSE file for details.

from cStringIO import StringIO
from hashlib import md5
from os import environ, listdir, remove, stat
from os.path import abspath, expanduser, join
from string import digits, letters
from sys import argv, exit
from urllib import quote as urlquote
from urllib2 import Request, urlopen
from xml.etree.ElementTree import Element, ElementTree, SubElement, parse

from flask import Flask, render_template
from simplejson import dumps as encode_json, load as decode_json
from yaml import dump as encode_yaml, safe_load as decode_yaml
from yatiblog.main import match_yaml_frontmatter, replace_yaml_frontmatter
from yatiblog.rst import render_rst

import config as cfg
try:
    import secret as cfg
except ImportError:
    pass

# ------------------------------------------------------------------------------
# App Config
# ------------------------------------------------------------------------------

app = Flask(__name__)
authors = dict((k, md5(v).hexdigest()) for k, v in cfg.AUTHORS.items())
cache = {}

base_url = "https://www.pivotaltracker.com/services/v3/projects"
stories_url = "%s/%s/stories" % (base_url, urlquote(cfg.PROJECT_ID))
static_url = "/static/" if cfg.DEBUG else cfg.STATIC_URL_BASE

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

def get_stories(token, render=True, offset=0, stories=None, url=stories_url):
    if stories is None:
        stories = []
    append = stories.append
    if offset:
        url += "?limit=3000&offset=%s" % offset
    data = parse(urlopen(Request(url, None,  {
        "User-Agent": "Pivotal-Web-Client", "X-TrackerToken": token
        })))
    seen = 0
    for story in data.iter('story'):
        id = story.findtext("id")
        text = story.findtext("description")
        updated = story.findtext("updated_at")
        if render:
            if id not in cache or updated != cache[id][0]:
                if text:
                    text = render_rst(text)
                cache[id] = (updated, text)
            else:
                text = cache[id][1]
        notes = []
        for note in story.iterfind("notes/note"):
            n_id = note.findtext("id")
            n_text = note.findtext("text")
            n_updated = note.findtext("noted_at")
            if render:
                c_id = "note-%s" % n_id
                if c_id not in cache or n_updated != cache[c_id][0]:
                    if n_text:
                        n_text = render_rst(n_text)
                    cache[c_id] = (n_updated, n_text)
                else:
                    n_text = cache[c_id][1]
            notes.append(dict(
                id=n_id,
                by=note.findtext("author"),
                text=n_text,
                updated=n_updated
                ))
        tags = story.findtext("labels", "")
        if tags:
            tags = tags.split(',')
        else:
            tags = []
        append(dict(
            id=id,
            type=story.findtext("story_type"),
            title=story.findtext("name"),
            state=story.findtext("current_state"),
            tags=tags,
            comments=notes,
            text=text,
            updated=updated))
        seen += 1
    if seen == 3000:
        get_stories(token, render, offset+3000, stories)
    return stories

def get_local_stories(path, render=True, cache={}):
    if render:
        stories = []; append = stories.append
    else:
        stories = {}
    for file in listdir(path):
        if file.startswith('.') or not file.endswith('.txt'):
            continue
        filepath = join(path, file)
        text = read(filepath)
        m_time = stat(filepath).st_mtime
        yaml = match_yaml_frontmatter(text)
        if not yaml:
            continue
        story = decode_yaml(yaml.group(1))
        id = story["id"]
        text = replace_yaml_frontmatter('', text)
        if render:
            if id not in cache or m_time != cache[id][0]:
                if text:
                    text = render_rst(text)
                cache[id] = (m_time, text)
            else:
                text = cache[id][1]
            story["text"] = render_rst(text)
            append(story)
        else:
            story["text"] = text
            stories[id] = file[:-4], story
    return stories

def read(file):
    f = open(file, 'rb')
    d = f.read()
    f.close()
    return d

def norm(id, alpha=letters+digits):
    res = []; out = res.append
    ins = 0
    for char in id:
        if char in alpha:
            if ins and res:
                out('-')
            ins = 0
            out(char)
        else:
            ins = 1
    return ''.join(res).lower()

def sync(path, clean):
    path = abspath(path)
    seen = set()
    if clean:
        for file in listdir(path):
            if file.startswith('.') or not file.endswith('.txt'):
                continue
            file = join(path, file)
            remove(file)
            print "# Removing: %s" % path
    print "# Syncing: %s" % path
    proj = read(join(path, '.pivotal-project-id')).strip()
    token = read(expanduser("~/.pivotal-token-%s" % proj)).strip()
    to_update = []; update = to_update.append
    stories = get_local_stories(path, 0)
    for idx, story in enumerate(get_stories(token, 0)):
        id = story["id"]
        filename = norm(story["title"])
        if filename in seen:
            ext = 1
            while "%s-%s" % (filename, ext) in seen:
                ext += 1
            filename = "%s-%s" % (filename, ext)
        seen.add(filename)
        story.pop("comments")
        if id in stories:
            filename, l_story = stories.pop(id)
            if story == l_story:
                continue
            if story["updated"] == l_story["updated"]:
                update((filename, l_story))
                continue
        filename = join(path, filename+'.txt')
        text = story.pop("text")
        print "# Writing: %s" % filename
        meta = encode_yaml(story, default_flow_style=False)
        file = open(filename, 'wb')
        file.write("---\n%s---\n\n%s" % (meta, text))
        file.close()
    for file, story in to_update:
        print "# Uploading: %s" % story["title"]
        id = story["id"]
        text = story.pop("text")
        root = Element("story")
        SubElement(root, "story_type").text = story["type"]
        SubElement(root, "name").text = story["title"]
        SubElement(root, "description").text = text
        SubElement(root, "labels").text = ','.join(story["tags"])
        io = StringIO()
        ElementTree(root).write(io)
        req = Request('%s/%s' % (stories_url, id), io.getvalue(), {
            "User-Agent": "Pivotal-Web-Client", "X-TrackerToken": token,
            "Content-Type": "application/xml"
            })
        req.get_method = lambda: 'PUT'
        story["updated"] = parse(urlopen(req)).findtext("updated_at")
        filename = join(path, file+'.txt')
        meta = encode_yaml(story, default_flow_style=False)
        print "# Updating: %s" % filename
        file = open(filename, 'wb')
        file.write("---\n%s---\n\n%s" % (meta, text))
        file.close()
    for file, _ in stories.values():
        filename = join(path, file+'.txt')
        q = raw_input("? Remove %s [Y/n] " % filename).lower()
        if q == "n":
            continue
        print "# Removing: %s" % filename
        remove(filename)

def STATIC(file, base=static_url, debug=cfg.DEBUG, assets={}):
    if debug or not assets:
        f = open('assets.json', 'rb')
        assets.update(decode_json(f))
        f.close()
    return "%s%s" % (base, assets[file])

# ------------------------------------------------------------------------------
# Handler
# ------------------------------------------------------------------------------

@app.route("/")
def root(cache=[], local=cfg.LOCAL_DIRECTORY, token=cfg.TRACKER_TOKEN):
    if cache:
        data = cache[0]
    else:
        print "lookup"
        if local:
            stories = get_local_stories(local)
        else:
            stories = get_stories(token)
        data = dict(authors=authors, stories=stories)
        data = encode_json(data).replace('/', r'\/')
        cache.append(data)
    return render_template('site.html', cfg=cfg, data=data, STATIC=STATIC)

# ------------------------------------------------------------------------------
# Script Runner
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    if argv[1:]:
        if argv[1] != "--sync" or len(argv) < 3:
            print "Usage: pivotal-sync <directory> [--clean]"
            exit(1)
        sync(argv[2], '--clean' in argv)
    else:
        port = int(environ.get("PORT", 5000))
        app.run(host='0.0.0.0', port=port, debug=cfg.DEBUG)
