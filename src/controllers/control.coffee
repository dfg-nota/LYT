# Requires `/common`
# Requires `/support/lyt/loader`
# Requires `/models/book/book`
# Requires `/models/member/settings`
# Requires `/models/service/service`
# Requires `/view/render`
# Requires `player`

# -------------------

# This is the main controller for the app. It handles most of the business-logic
# involved in displaying the requested pages

# TODO: Rename to controller (not control)

LYT.control =

  # ---------------
  # Utility methods

  init: ->
    @versionCheck()
    @setupEventHandlers()

  versionCheck: ->
    lastVersion = ->
      # For debugging: let the user specify lastVersion in the address
      if match = window.location.hash.match /lastVersion=([0-9\.]+)/
        return match[1]
      if version = LYT.cache.read 'lyt', 'lastVersion'
        return version
      if LYT.cache.read 'session', 'credentials' or LYT.cache.read 'lyt', 'settings'
        return '0.0.2'

    if lastVersion() and lastVersion() isnt LYT.VERSION
      LYT.var.next = window.location.hash
      window.location.hash = '#splash-upgrade'
    LYT.cache.write 'lyt', 'lastVersion', LYT.VERSION

  setupEventHandlers: ->
    $("#bookmark-add-button").on 'click', ->
      if (segment = LYT.player.currentSegment) and segment.canBookmark
        LYT.player.book.addBookmark segment, LYT.player.getStatus().currentTime
        LYT.render.bookmarkAddedNotification()

    # Hacking away on book index page that is mostly being rendered by
    # the nested list view in jQuery Mobile.
    # This click handler does several things:
    #  - Make the back button (currently "Tilbage") go back
    #  - Make navigation to lower levels of the book index work
    #  - Leave it to the normal list view to handle other click events
    #
    # The click handler is on #book-index because selecting .create-listview,
    # doesn't capture clicks, since the list is dynamically created.
    $('#book-index').on 'click', '.create-listview', (event) ->
      ev = $(this)
      if ev.length isnt 0
        # The click is for us
        view = $.mobile.activePage.children ':jqmData(role=content)'
        book = LYT.player.book
        iterate = (items) ->
          for item in items
            if item.id == ev.attr("nodeid")
              LYT.render.createbookIndex item.children, view, book, item
              break
            else if item.children.length > 0
              iterate item.children
        if ev.attr("nodeid")?
          event.stopPropagation()
          if ev.attr("nodeid") is "0"
            LYT.render.createbookIndex book.nccDocument.structure, view, book
          else
            iterate book.nccDocument.structure

    $(window).resize -> LYT.player.refreshContent()

    $("#login-form").submit (e) ->
      e.preventDefault()
      e.stopPropagation()

      $form = $(this)
      $form.find("#password").blur()

      process = LYT.service.logOn($form.find("#username").val(), $form.find("#password").val())
        .done ->
          log.message 'control: login: logOn done'
          next = LYT.var.next
          LYT.var.next = null
          next = LYT.config.defaultPage.hash if not next? or next is "#login" or next is ""
          $.mobile.changePage next

        .fail ->
          log.warn 'control: login: logOn failed'
          parameters =
            mode:                'bool'
            prompt:              LYT.i18n('Incorrect username or password')
            subTitle:            LYT.i18n('')
            animate:             false
            useDialogForceFalse: true
            allowReopen:         true
            useModal:            true
            buttons:             {}
          parameters.buttons[LYT.i18n('OK')] =
            click: -> # Nop
            theme: 'c'
          LYT.render.showDialog($("#login-form"), parameters)

      # Clear password field
      $form.find('#password').val ''

      LYT.loader.register "Logging in", process

    Modernizr.on 'playbackratelive', (playbackratelive) ->
      if not Modernizr.playbackrate and not playbackratelive
        LYT.render.disablePlaybackRate()

    $("#style-settings input").change ->
      target = $(this)
      name = target.attr 'name'
      val = target.val()

      style = jQuery.extend {}, (LYT.settings.get "textStyle" or {})

      switch name
        when 'font-size', 'font-family'
          style[name] = val
        when 'marking-color'
          colors = val.split(';')
          style['background-color'] = colors[0]
          style['color'] = colors[1]
          # TODO: use lower case just like all the other parameters
        when 'playback-rate'
          val = Number(val)
          LYT.settings.set('playbackRate', val)
          LYT.player.setPlaybackRate val
        when 'word-highlighting'
          isOn = target.prop "checked"
          LYT.render.setHighlighting isOn
          LYT.settings.set('wordHighlighting', isOn)

      LYT.settings.set('textStyle', style)
      LYT.render.setStyle()

    $('#instrumentation').find('button.first').on 'click', ->
      LYT.render.instrumentationGraph()?.firstEntry()

    $('#instrumentation').find('button.last').on 'click', ->
      LYT.render.instrumentationGraph()?.lastEntry()

    $('#instrumentation').find('button.previous').on 'click', ->
      LYT.render.instrumentationGraph()?.previousEntry()

    $('#instrumentation').find('button.next').on 'click', ->
      LYT.render.instrumentationGraph()?.nextEntry()

    $('#run-tests').one 'click', ->
      $('#run-tests').button 'disable'
      deferred = $.mobile.util.waitForConfirmDialog LYT.i18n('Is this the first test run?')
        .done ->
          LYT.settings.reset()
          LYT.player.setPlaybackRate 1
        .always ->
          QUnit.start()

    QUnit.begin ->
      $('.test-results').text ''
      $('.test-tab').addClass 'started'
      $('.test-tab').removeClass 'error'

    QUnit.testStart (test) ->
      $('.test-results').text ": #{test.name}"

    QUnit.testDone (test) ->
      $('.test-results').text ": #{test.name}: #{test.passed}/#{test.total}"
      $('.test-tab').addClass if test.failed == 0 then 'done' else 'error'
      test_name = test.name.replace /\s+/g, '_'
      LYT.test.fixtures.results[test_name] or= []
      (test.assertions or []).forEach (assertion) ->
        LYT.test.fixtures.results[test_name].push assertion

    QUnit.done ->
      $.post '/test/results',
        userAgent: navigator.userAgent
        testResults: LYT.test.fixtures.results
      $.mobile.changePage "#test"

    QUnit.log (event) ->
      method = if event.result then log.message else log.error
      method "Test: #{event.message}: passed: #{event.result}"

    Mousetrap.bind 'alt+ctrl+m', ->
      $("#bookmark-add-button").click()

    $('.open-log-console').on 'click', ->
      log.receiver = 'devconsole'
      log.level = 3
      log.message 'Opened developer console'

  ensureLogOn: (params) ->
    deferred = jQuery.Deferred()
    if credentials = LYT.session.getCredentials()
      deferred.resolve credentials
    else
      if params?.guest?
        promise = LYT.service.logOn(LYT.config.service.guestUser, LYT.config.service.guestLogin)
        LYT.loader.register 'Logging in', deferred.promise()
        promise.done -> deferred.resolve()
        promise.fail -> deferred.reject()
      else
        LYT.var.next = window.location.hash
        $.mobile.changePage '#login'
        $(LYT.service).one 'logon:resolved', -> deferred.done()
        $(LYT.service).one 'logon:rejected', -> deferred.fail()

    deferred.promise()

  # ----------------
  # Control handlers

  login: (type, match, ui, page, event) ->
    $page = $(page)
    if type is 'pageshow'
      $page.find('#username').focus()
      $page.find('#submit').button('enable')
    else
      $page.find('#submit').button('disable')

  # TODO: Move bookmarks list to separate page
  # TODO: Bookmarks and toc does not work properly after a forced refresh on the #book-index page. Needs to be fixed when force reloading the entire app.
  bookIndex: (type, match, ui, page, event) ->
    params = LYT.router.getParams(match[1])
    return if params?['ui-page']
    promise = LYT.control.ensureLogOn params
    promise.fail -> log.error 'Control: bookIndex: unable to log in'
    promise.done ->
      bookId = params?.book or LYT.player.book?.id
      if not bookId
        $.mobile.changePage LYT.config.defaultPage.hash
        return
      content = $(page).children ':jqmData(role=content)'

      # Remove any previously generated index (may be from another book)
      LYT.render.clearContent content

      activate = (active, inactive, handler) ->
        $(active).addClass 'ui-btn-active'
        $(inactive).removeClass 'ui-btn-active'

      renderBookmarks = ->
        #TODO:  Check if book is different than last time we checked...
        #return if $("#bookmark-list-button.ui-btn-active").length != 0
        activate "#bookmark-list-button", "#book-toc-button", renderIndex
        promise = LYT.Book.load bookId
        promise.done (book) -> LYT.render.bookmarks book, content
        LYT.loader.register "Loading bookmarks", promise

      renderIndex = ->
        #TODO:  Check if book is different than last time we checked...
        #return if $("#book-toc-button.ui-btn-active").length != 0
        activate "#book-toc-button", "#bookmark-list-button", renderBookmarks
        promise = LYT.Book.load bookId
        promise.done (book) -> LYT.render.bookIndex book, content
        LYT.loader.register "Loading index", promise

      $("#bookmark-list-button").click -> renderBookmarks()
      $("#book-toc-button").click -> renderIndex()

      renderIndex()

  bookPlayer: (type, match, ui, page, event) ->
    params = LYT.router.getParams(match[1])
    if not params? or not params.book?
      return

    if type is 'pagebeforeshow'
      # Make sure we're looking good
      LYT.render.setStyle()

      # Stop playback if we are going to switch to another book
      if LYT.player.book?.id and params.book isnt LYT.player.book.id
        LYT.player.stop()
        LYT.render.clearBookPlayer()

    promise = LYT.control.ensureLogOn params
    promise.fail -> log.error 'Control: bookPlay: unable to get login'
    promise.done ->
      if type is 'pageshow'
        LYT.player.refreshContent(true) if LYT.player.book?.id is params.book

        # Switch to different (part of) book
        # Because of bad naming, sections are here actually SMIL
        # files with an optional fragment. We're keeping params.section
        # for backwards-compatibility
        if params.smil or params.section
          smil = params.smil or params.section
          smilReference = smil
          if params.fragment
            smilReference += "##{params.fragment}"
          else if params.segment
            smilReference += "##{params.segment}"

          offset = if params.offset then LYT.utils.parseTime(params.offset) else null
        else if LYT.player.book?.id is params.book
          # We're already playing this book, so we just continue playing.
          return

        play = params.play is 'true'
        LYT.render.content.focusEasing params.focusEasing if params.focusEasing
        LYT.render.content.focusDuration parseInt params.focusDuration if params.focusDuration

        # If this section is already playing, don't do anything
        if LYT.player.book? and params.fragment? and
           params.fragment is LYT.player.currentSection().fragment
          return

        log.message "Control: bookPlay: loading book #{params.book}"

        process = LYT.player.load params.book, smilReference, offset, play
        process.done (book) ->
          LYT.render.bookPlayer book, $(page)
          # See if there are any service announcements every time a new book has been loaded
          LYT.service.getAnnouncements()
          LYT.player.refreshContent()
          LYT.player.setFocus()
          pageTitle = "#{LYT.i18n('Now playing')} #{LYT.player.book.title}"
          LYT.render.setPageTitle pageTitle

          if params.smil? or params.section? or params.offset?
            # When the user selects a 'chapter' or bookmark in #book-index and afterwars open #settings
            # and clicks 'back'-button, the player would go back to the last selected 'chapter' or
            # bookmark.
            # We solve this by updating the hash to only include the params book and from.
            newPath = "book-player?book=#{params.book}" + if params.from? then "&from=#{params.from?}" else ""
            if $.mobile.pushStateEnabled and $.isFunction( window.history.replaceState )
              # Browsers that support pushState, replace the history entry with the new hash,
              # this prevents double entries in our history.
              window.history.replaceState {}, pageTitle, "##{newPath}"
            else
              # Browser without support for pushStat (e.g. IE9) will have to live with
              # the double entry in history.
              window.location.hash = newPath

        process.fail (error) ->
          log.error "Control: bookPlay: Failed to load book ID #{params.book}, reason: #{error}"

          # Hack to fix books not loading when being redirected directly from login page
          if LYT.session.getCredentials()?
            if LYT.var.next? and ui.prevPage[0]?.id is 'login'
              window.location.reload()
            else
              parameters =
                mode:                'bool'
                prompt:              LYT.i18n('Unable to retrieve book')
                subTitle:            LYT.i18n('')
                animate:             false
                useDialogForceFalse: true
                allowReopen:         true
                useModal:            true
                buttons: {}
              parameters.buttons[LYT.i18n('Try again')] =
                click: -> window.location.reload()
                icon:  'refresh'
                theme: 'c'
              parameters.buttons[LYT.i18n('Cancel')] =
                click: -> $.mobile.changePage LYT.config.defaultPage.hash
                icon:  'delete'
                theme: 'c'
              LYT.render.showDialog($.mobile.activePage, parameters)
        # else just show book player (done by default by the router)

  settings: (type, match, ui, page, event) ->
    params = LYT.router.getParams(match[1])
    promise = LYT.control.ensureLogOn params
    promise.fail -> log.error 'Control: settings: unable to log in'
    promise.done ->
      if type is 'pagebeforeshow'
        if LYT.config.settings.showAdvanced
          $('.advanced-settings').show()
        else
          $('.advanced-settings').hide()

      if type is 'pageshow'
        style = jQuery.extend {}, (LYT.settings.get "textStyle" or {})

        $("#style-settings").find("input").each ->
          el = $(this)
          name = el.attr 'name'
          val = el.val()

          # Setting the GUI
          switch name
            when 'font-size', 'font-family'
              if val is style[name]
                el.attr("checked", true).checkboxradio("refresh")
            when 'marking-color'
              colors = val.split(';')
              if style['background-color'] is colors[0] and style['color'] is colors[1]
                el.attr("checked", true).checkboxradio("refresh")
            when 'playback-rate'
              if Number(val) is LYT.settings.get('playbackRate')
                el.attr("checked", true).checkboxradio("refresh")
            when 'word-highlighting'
              el.prop("checked", LYT.settings.get("wordHighlighting"))
                .checkboxradio("refresh")

  splashUpgrade: (type, match, ui, page, event) ->
    params = if match[1] then LYT.router.getParams(match[1]) else {}
    # Display deprecation notice in case browser support is going to stop
    if params['deprecation-notice'] or $.browser.msie and $.browser.version.match /^8(\.|$)/
      $('.deprecation-notice').show()
      $('#splash-upgrade-button').on 'click', ->
        $(document).one 'pagechange', -> $.mobile.silentScroll $('#supported-platforms').offset().top
        $.mobile.changePage '#support'
    else
      goto = if LYT.var.next and not LYT.var.next.match /^#splash-upgrade/ then LYT.var.next else LYT.config.defaultPage.hash
      $('#splash-upgrade-button').on 'click', -> $.mobile.changePage goto

  instrumentation: (type, match, ui, page, event) ->
    if type is 'pagebeforeshow'
      LYT.render.showInstrumentation $('#instrumentation-content')

  test:  (type, match, ui, page, event) ->
    if type is 'pageshow'
      setTimeout(
        ->
          $(page).trigger 'create'
        100
      )
      LYT.render.hideTestTab()
    else if type is 'pagehide'
      LYT.render.showTestTab()

  defaultPage: -> $.mobile.changePage(LYT.config.defaultPage.hash)
