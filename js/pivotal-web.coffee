# Public Domain (-) 2011 The Pivotal Web Authors.
# See the Pivotal Web UNLICENSE file for details.

# ------------------------------------------------------------------------------
# Namespace Support
# ------------------------------------------------------------------------------

# The ``namespace`` function provides a utility wrapper to namespace code
# blocks. If an explicit target isn't passed in, it defaults to using ``window``
# as the top-level object.
window.namespace = (target, name, block) ->
  [target, name, block] = [window, arguments...] if arguments.length < 3
  top = target
  target = target[item] or= {} for item in name.split '.'
  block target, top

# ------------------------------------------------------------------------------
# Array Utilities
# ------------------------------------------------------------------------------

namespace 'array', (exports, root) ->

  indexOf = Array::indexOf

  exports.contains = (array, item) ->
    if indexOf and array.indexOf is indexOf
      return array.indexOf(item) != -1
    for elem in array
      if elem is item
        return true
    return false

  exports.remove = (array, item) ->
    i = 0
    while i < array.length
      if array[i] is item
        array.splice(i, 1)
      else
        i += 1
    return

# ------------------------------------------------------------------------------
# Browser Support
# ------------------------------------------------------------------------------

namespace 'browser', (exports, root) ->

  # The ``browser.validateSupport`` function checks if certain "modern" browser
  # features are available and prompts the user to upgrade if not.
  exports.validateSupport = ->
    exports.update() if not JSON?

  # The various modern HTML5 browsers that are supported. It's quite possible
  # that other popular browsers like IE and Opera will also be compatible at
  # some point soon, but testing is needed before adding them to this list.
  supported = [
    ['chrome', 'Chrome', 'http://www.google.com/chrome',
     '5b8e7344541bb6c3164611052727e57e45525fb1']
    ['firefox', 'Firefox', 'http://www.mozilla.org/en-US/firefox/new/',
     'da9bfa7ebf72e5359cdc9ab5af5e3ab8e73d8514']
    ['safari', 'Safari', 'http://www.apple.com/safari/',
     'd3ad22a85773dbb275d0e0fe11a3827a2d9cca94']
  ]

  # exports.

  exports.update = ->
    $container = $ '''
      <div class="update-browser">
        <h1>Please Upgrade to a Recent Browser</h1>
      </div>
      '''
    $browserListDiv = $ '<div class="listing"></div>'
    $browserList = $ '<ul></ul>'
    for [id, name, url, imgHash] in supported
      $browser = $ """
        <li>
          <a href="#{url}" title="Upgrade to #{name}" class="img">
            <img src="#{STATIC_HOST}gfx/#{imgHash}-browser.#{id}.png" alt="#{name}" />
          </a>
          <div>
            <a href="#{url}" title="Upgrade to #{name}">
              #{name}
            </a>
          </div>
          </a>
        </li>
        """ # emacs "
      $browser.appendTo $browserList
    $browserList.appendTo $browserListDiv
    $browserListDiv.appendTo $container
    $container.appendTo '#stories'
    return true

# ------------------------------------------------------------------------------
# Google Analytics
# ------------------------------------------------------------------------------

namespace 'services.analytics', (exports, root) ->

  exports.setup = ->

    if document.location.protocol is 'file:'
      return

    if document.location.hostname is 'localhost'
      return

    if GOOGLE_ANALYTICS_ID?

      _gaq = []
      _gaq.push ['_setAccount', GOOGLE_ANALYTICS_ID]
      _gaq.push ['_setDomainName', GOOGLE_ANALYTICS_HOST]
      _gaq.push ['_trackPageview']

      root._gaq = _gaq

      (->
        ga = document.createElement 'script'
        ga.type = 'text/javascript'
        ga.async = true
        if document.location.protocol is 'https:'
          ga.src = 'https://ssl.google-analytics.com/ga.js'
        else
          ga.src = 'http://www.google-analytics.com/ga.js'
        s = document.getElementsByTagName('script')[0]
        s.parentNode.insertBefore(ga, s)
        return
      )()

    return

# ------------------------------------------------------------------------------
# Humane Interface
# ------------------------------------------------------------------------------

namespace 'humane', (exports, root) ->

  alpha = {}
  for char in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('')
    alpha[char] = true

  exports.alpha = alpha
  exports.id = (id, cache) ->
    res = []
    ins = false
    for char in id.split('') # TODO(tav): Do this properly.
      if alpha[char]
        if ins and res.length > 0
          res.push '-'
        ins = false
        res.push char
      else
        ins = 1
    normalised = res.join('').toLowerCase()
    if cache[normalised]
      suffix = 1
      while cache["#{normalised}-#{suffix}"]
        suffix += 1
      normalised = "#{normalised}-#{suffix}"
    cache[normalised] = true
    return normalised

  now = (new Date()).getTime()

  exports.time = (timestamp, force) ->
    if force
      present = (new Date()).getTime()
    else
      present = now
    delta = (present - timestamp) / 1000
    if (delta < 60)
      return "less than " + Math.floor(delta) + " seconds ago"
    delta = Math.floor(delta / 60)
    if (delta == 0)
      return 'less than a minute ago'
    if (delta == 1)
      return 'a minute ago'
    if (delta < 60)
      return delta + ' minutes ago'
    if (delta < 62)
      return 'about 1 hour ago'
    if (delta < 120)
      return 'about 1 hour and ' + (delta - 60) + ' minutes ago'
    if (delta < 1440)
      return 'about ' + Math.floor(delta / 60) + ' hours ago'
    if (delta < 2880)
      return '1 day ago'
    if (delta < 43200)
      return Math.floor(delta / 1440) + ' days ago'
    if (delta < 86400)
      return 'about 1 month ago'
    if (delta < 525960)
      return Math.floor(delta / 43200) + ' months ago'
    if (delta < 1051199)
      return 'about 1 year ago'
    return 'over ' + Math.floor(delta / 525960) + ' years ago'

# ------------------------------------------------------------------------------
# Object Utilities
# ------------------------------------------------------------------------------

namespace 'object', (exports, root) ->

  exports.sortKeys = (obj) ->
    keys = (key for own key of obj)
    keys.sort()
    return keys

  exports.sortToArray = (obj) ->
    keys = (key for own key of obj)
    keys.sort()
    obj[key] for key in keys

# ------------------------------------------------------------------------------
# Pivotal Web App
# ------------------------------------------------------------------------------

namespace 'pivotal', (exports, root) ->

  done = '<span class="state">✓</span>'
  todo = '<span class="state">✗</span>'

  state2text =
    accepted: 'DONE'
    delivered: 'IN REVIEW'
    finished: 'NEEDS REVIEW'
    rejected: 'REJECTED'
    started: 'WIP'
    unscheduled: 'TODO'
    unstarted: 'TODO'

  state2class =
    'DONE': 'done'
    'IN REVIEW': 'in-review'
    'NEEDS REVIEW': 'needs-review'
    'REJECTED': 'rejected'
    'WIP': 'wip'
    'TODO': 'todo'

  statesList = [
    'TODO'
    'WIP'
    'NEEDS REVIEW'
    'IN REVIEW'
    'DONE'
  ]

  state2done =
    accepted: true
    delivered: true
    finished: true
    rejected: false
    started: false
    unscheduled: false
    unstarted: false

  $all = null
  $states = {}
  filters = {}

  fragmentCache = {}
  exports.filters = filters

  setupFilter = (tag, filterID, $filters, isState) ->
    filterID = String(filterID)
    $div = $ '<div />'
    $input = $ """<input type="checkbox" id="filter-#{filterID}" value="#{filterID}" />"""
    $input.click ->
      triggerFilter(filterID, isState)
    $input.appendTo $div
    $div.append """<label for="filter-#{filterID}" class="tag tag-label">#{tag}</label>"""
    $div.appendTo $filters
    if tag is "SHOW ALL"
      $all = $input
    else if isState
      $states[filterID] = [tag, $input]
    else
      filters[tag] = $input
    return

  triggerFilter = (filterID, isState) ->
    # Special case "SHOW ALL" being selected.
    if filterID is '1'
      for own tag, $input of filters
        $input.attr("checked", false)
      for own tag, [_, $input] of $states
        $input.attr("checked", false)
      showAll()
    else
      $all.attr('checked', false)
    show = []
    if isState
      [state, $input] = $states[filterID]
      if $input.is(':checked')
        show.push state
        for own stateID, [_, $input] of $states
          if stateID != filterID
            $input.attr('checked', false)
    else
      for own _, [state, $input] of $states
        if $input.is(':checked')
          show.push state
    for own tag, $input of filters
      if $input.is(':checked')
        show.push tag
    showStories show
    return

  showAll = ->
    $all.attr('checked', true)
    for story in exports.overviewStories
      if story._root
        story.html.show()
      else
        story.html.hide()
    for story in exports.stories
      story.html.show()
    if window.location.hash
      window.location.hash = "#"

  showStories = (show) ->
    l = show.length
    if l is 0
      showAll()
      return
    for story in exports.overviewStories
      story.html.hide()
    if l is 1
      tag = show[0]
      if string.startswith(tag, '#') and overviews[tag]
        overviews[tag].html.show()
    _states = []
    _tags = []
    _users = []
    for tag in show
      if string.startswith(tag, '#')
        _tags.push tag
      else if string.startswith(tag, '@')
        _users.push tag
      else if state2class[tag]
        _states.push tag
    for story in exports.stories
      match = true
      for tag in _states
        if tag != story._state
          match = false
          break
      if not match
        story.html.hide()
        continue
      for tag in _tags
        if not array.contains(story._tags, tag)
          match = false
          break
      if not match
        story.html.hide()
        continue
      for tag in _users
        if not array.contains(story._users, tag)
          match = false
          break
      if not match
        story.html.hide()
        continue
      story.html.show()
    window.location.hash = '#' + show.join ','
    return

  exports.overviews = overviews = {}
  exports.states = states = {}
  exports.stories = stories = []
  exports.tags = tags = {}
  exports.users = users = {}

  exports.setup = ->

    $filters = $ '#filters'
    $sidebar = $ '#sidebar'
    $stories = $ '#stories'

    for story in PIVOTAL_DATA['stories']

      # Ignore all rejected stories.
      if story.state is "rejected"
        continue

      # Extract all overview stories.
      remove = false
      for tag in story.tags
        if string.endswith(tag, ':overview')
          if tag is ':overview'
            overviews[''] = story
            story._root = true
          if string.startswith(tag, '#')
            tag = tag.slice(0, tag.lastIndexOf(':overview'))
            overviews[tag] = story
          remove = true

      if remove
        continue

      story._tags = []
      story._users = []

      # Handle the #tags and @users for the story.
      for tag in story.tags
        if string.startswith(tag, '#')
          if not tags[tag]
            tags[tag] = []
          tags[tag].push story
          story._tags.push tag
        else if string.startswith(tag, '@')
          if not users[tag]
            users[tag] = []
          users[tag].push story
          story._users.push tag

      # Handle the story state.
      state = story.state
      newState = story._state = state2text[state]
      story._done = state2done[state]

      if not states[newState]?
        states[newState] = []
      states[newState].push story

      # Append the story to the stories list.
      stories.push story

    # Sort the overview stories.
    exports.overviewStories = overviewStories = object.sortToArray overviews

    # Pre-render the overview stories.
    for story in overviewStories
      story.html = $html = $ """
      <div id="#{story.id}" class="story-overview">
        #{story.text}
      </div>
      """ # emacs "
      $html.hide()
      $html.appendTo $stories

    # Pre-render the base stories.
    for story in stories
      if story._done
        state = done
      else
        state = todo
      _tags = []
      for tag in story._tags
        _tags.push("""<span class="tag tag-topic">#{tag}</span>""")
      for user in story._users
        _tags.push("""<span class="tag tag-user">#{user}</span>""")
      _tags = _tags.join ' '
      fragID = humane.id(story.title, fragmentCache)
      story.html = $html = $ """
      <div id="item-#{fragID}" class="story">
        <a href="https://www.pivotaltracker.com/projects/#{PIVOTAL_ID}?story_id=#{story.id}"
           target="_blank" class="story-title">#{state} &nbsp; #{story.title}</a>
        <div class="story-text">#{story.text}</div>
        <div class="right small">
          <a href="#item-#{fragID}" class="time">#{humane.time(story.updated)}</a>
          <span class="tags">
            <span class="tag tag-#{state2class[story._state]}">#{story._state}</span>
            #{_tags}
          </span>
        </div>
      </div>
      """ # emacs "
      $html.hide()
      $html.appendTo $stories

    setupFilter('SHOW ALL', 1, $filters)
    $('<br/>').appendTo $filters
    filterID = 2

    for state in statesList
      setupFilter(state, filterID, $filters, true)
      filterID += 1

    $('<br/>').appendTo $filters

    for tag in object.sortKeys(tags)
      setupFilter(tag, filterID, $filters)
      filterID += 1

    $('<br/>').appendTo $filters

    for user in object.sortKeys(users)
      setupFilter(user, filterID, $filters)
      filterID += 1

    # Show stories.
    if window.location.hash
      fragment = window.location.hash.substr(1)
      if not string.startswith(fragment, 'item-')
        request = (decodeURIComponent(t) for t in fragment.split(','))
        for _req in request
          if string.startswith(_req, '#') or string.startswith(_req, '@')
            if filters[_req]
              filters[_req].attr('checked', true)
          else if state2class[_req]
            for _, [_state, $html] of $states
              if _req is _state
                $html.attr('checked', true)
        showStories(request)
      else
        showAll()
    else
      showAll()

    # Reveal the sidebar.
    $sidebar.show()

# ------------------------------------------------------------------------------
# String Utilities
# ------------------------------------------------------------------------------

namespace 'string', (exports, root) ->

  exports.endswith = (str, suffix) ->
    diff = str.length - suffix.length
    diff >= 0 and str.indexOf(suffix, diff) is diff

  exports.startswith = (str, prefix) ->
    str.lastIndexOf(prefix, 0) is 0

# ------------------------------------------------------------------------------
# TypeKit Loader
# ------------------------------------------------------------------------------

namespace 'services.typekit', (exports, root) ->

  exports.setup = ->
    try
      Typekit.load()
    catch error
      return

# ------------------------------------------------------------------------------
# On Load
# ------------------------------------------------------------------------------

initApp = ->
  services.analytics.setup()
  if browser.validateSupport()
    return
  pivotal.setup()

# ------------------------------------------------------------------------------
# Startup
# ------------------------------------------------------------------------------

services.typekit.setup()
$(initApp)
