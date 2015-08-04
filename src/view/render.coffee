# Requires `/common`
# Requires `/controllers/player`
# Requires `/models/member/settings`

# -------------------

# This module handles gui callbacks and various utility functions
#console.log 'Load LYT.render'

LYT.render = do ->

  # ## Privileged API

  # Default book cover image
  defaultCover = '/images/icons/default-cover.png'

  loadCover = (img, id) ->
    # if periodical, use periodical code (first 4 letters of id)
    imageid = if $.isNumeric(id) then id else id.substring(0, 4)
    img.attr 'src', "http://bookcover.e17.dk/#{imageid}_h200.jpg"


  # Displays a small speech bubble notification vertOffset pixels below the
  # provided element containing the provided text for timeout milliseconds.
  # If timeout provided is zero, the bubble will display until the user clicks
  # it. Timeout defaults to 5000.
  # Returns a function that will remove the notification when called.
  bubbleNotification = (element, text, vertOffset=0, timeout) ->
    notification = $("<div class=\"bubble-notification\" role=\"alert\"><div class=\"bubble-notification-arrow\"></div><div class=\"bubble-notification-message\">#{text}</div></div>")
    # We set visibility to hidden and attach it to body in order to measure the width
    notification.css 'visibility', 'hidden'
    $('body').append notification
    notification.css 'left', element.offset().left - notification.width()/2 + element.width()/2
    notification.css 'top', element.offset().top + element.height() + vertOffset
    notification.hide()
    notification.css 'visibility', ''
    notification.fadeIn()
    remove = ->
      notification.removeAttr('role')
      notification.fadeOut ->
        notification.remove()
    if timeout == 0
      notification.on 'click', remove
    else
      setTimeout(remove, timeout or 5000)
    remove

  setSelectSectionEvent = (list) ->
    # event for opening a section/bookmark in a given book
    list.on 'click', '.section-link', (e) ->
      # A section/bookmark link was clicked, skip to that section in the book
      el = $(e.target)
      book = "#{el.data 'book'}"

      # Not the same book, just return
      unless book and book is LYT.player.book?.id
        log.message "LYT.render: setSelectSectionEvent: not the current book #{book} isn't #{LYT.player.book?.id}"
        return

      smilReference = el.data 'smil'
      if fragment = el.data 'fragment'
        smilReference += "##{fragment}"

      if segment = el.data 'segment'
        smilReference += "##{segment}"

      if offset = el.data 'offset'
        offset = LYT.utils.parseTime(offset)
      else
        offset = null

      # TODO: Workout why LYT.player.load won't respect play == true from here
      progress = LYT.player.load LYT.player.book?.id, smilReference, offset, true
      progress.done ->
        # TODO: For some reason LYT.player.load() won't respect play === true from this event
        # I assume it has something to do with the bookPlayer controller.
        LYT.player.stop().then ->
          LYT.player.play()

  # ---------------------------

  # ## Public API

  bubbleNotification: bubbleNotification

  init: ->
    log.message 'Render: init'
    @setStyle()
    @setInfo()

  setStyle: ->
    log.message 'Render: setting custom style'
    # TODO: Dynamic modification of a CSS class in stead of this
    $('#textarea-example, #book-context-content, #book-plain-content').css(
      LYT.settings.get('textStyle')
    )

    # Set word highlighting if appropriate
    LYT.render.setHighlighting LYT.settings.get('wordHighlighting')

  setHighlighting: (highlight) ->
    # Set highlight on by default
    if not highlight?
      LYT.settings.set 'wordHighlighting', true
      highlight = true

    viewer = $('#book-context-content')
    if viewer.hasClass 'word-highlight'
      viewer.removeClass 'word-highlight' if not highlight
    else
      viewer.addClass 'word-highlight' if highlight

  setInfo: ->
    $('.lyt-version').html LYT.VERSION
    $('.current-year').html (new Date()).getFullYear()

  bookmarkAddedNotification: -> LYT.render.bubbleNotification $('#book-index-button'), 'Bogmærke tilføjet', 5

  disablePlaybackRate: ->
    # Wait with disabling until it's actually created
    $playbackRate = $('#playback-rate')
    $playbackRate.find('.message.disabled').show()
    $playbackRate
      .find('input[type="radio"]').on( 'checkboxradiocreate', ->
        $(this).checkboxradio('disable')
      ).each ->
        el = $(this)
        if el.data('mobileCheckboxradio')?
          el.checkboxradio('disable')
        else
          el.prop('disabled',true)

  clearBookPlayer: ->
    @clearTextContent()
    playerInfo = $('#player-info')

    playerInfo.find('#player-book-title').text ''
    playerInfo.find('#player-book-author').text ''
    playerInfo.find('#currentbook-image img').attr 'src', defaultCover
    playerInfo.find('.player-book-info h1 .player-book-title-author, .player-chapter-title').hide()
    @disablePlayerNavigation()

  clearContent: (content) ->
    list = content.children 'ol, ul'
    if list.length and list.hasClass 'ui-listview'
      if list.listview('childPages').length > 0
        list.listview('childPages').remove()
        list.listview 'refresh'
      else
        list.listview().children().remove()

  enablePlayerNavigation: ->
    $('#book-play-menu').find('a').add('#book-index-button,#bookmark-add-button').removeClass 'ui-disabled'

  disablePlayerNavigation: ->
    $('#book-play-menu').find('a').add('#book-index-button,#bookmark-add-button').addClass 'ui-disabled'

  isPlayerNavigationEnabled: ->
    $.makeArray($('#book-play-menu').find('a').add('#book-index-button,#bookmark-add-button')).some (el) ->
      !$(el).hasClass 'ui-disabled'

  bookPlayer: (book, view) ->
    playerInfo = $('#player-info')

    playerInfo.find('#player-book-title').text book.title
    playerInfo.find('#player-book-author').text book.author
    playerInfo.find('.player-book-info h1 .player-book-title-author, .player-chapter-title').show()
    loadCover playerInfo.find('#currentbook-image img'), book.id
    @enablePlayerNavigation()

  showAnnouncements: (announcements) ->
    #for announcement in announcements
     # if announcement.text?
       # alert announcement.text #Stops processing of javascript (alert)...

    #LYT.service.markAnnouncementsAsRead(announcements)


  bookEnd: () -> LYT.render.content.renderText LYT.i18n('The end of the book')

  clearTextContent: -> LYT.render.content.renderSegment()

  textContent: (segment) ->
    return unless segment
    # Set enable or disable add bookmark button depending on we can bookmark
    if segment.canBookmark
      $('.ui-icon-bookmark-add').removeClass 'disabled'
      $('#bookmark-add-button').attr 'title', LYT.i18n('Bookmark location')
    else
      $('.ui-icon-bookmark-add').addClass 'disabled'
      $('#bookmark-add-button').attr 'title', LYT.i18n('Unable to bookmark location')
    LYT.render.content.renderSegment segment

  bookIndex: (book, view) ->
    # FIXME: We should be using asking the book for a TOC, not the NCC directly
    # since this is a sign of lack of decoupling
    @createbookIndex book.nccDocument.structure, view, book

  createbookIndex: (items, view, book, root = null) ->
    curSection = LYT.player.currentSection()
    curParentID = curSection.id.substr 0, curSection.id.search /(\.\d$)|$/

    isPlaying = (item) ->
      return unless String(book.id) is String(LYT.player.book.id)
      return unless item.ref is curSection.ref or curParentID is item.id
      return true

    sectionLink = (section) ->
      title = section.title?.replace("\"", "") or ""

      "<a class=\"gatrack section-link\" ga-action=\"Link\" " +
      "data-book=\"#{book.id}\" data-smil=\"#{section.url}\" " +
      "data-fragment=\"#{section.fragment}\" " +
      "data-ga-book-id=\"#{book.id}\" data-ga-book-title=\"#{title}\" " +
      "href=\"#book-player?book=#{book.id}\">#{title}</a>"

    $('#index-back-button').removeAttr 'nodeid'

    if root?.title?
      $('#index-back-button').attr 'nodeid', String(root.parent)

    view.children().remove()
    list = $('<ul data-role="listview" data-split-theme="a"></ul>').hide()
    view.append list
    list.attr 'data-title', book.title
    list.attr 'data-author', book.author
    list.attr 'data-totalTime', book.totalTime
    list.attr 'id', 'NccRootElement'

    for item in items
      if item.children.length > 0
        element = jQuery '<li data-icon="arrow_icn"></li>'
        element.append sectionLink item
        element.append """<a nodeid="#{item.id}" class="create-listview subsection">underafsnit</a>"""
      else
        element = jQuery '<li data-icon="false"></li>'
        element.append sectionLink item
        element.attr 'id', item.id
        element.attr 'data-href', item.id

      if isPlaying item
        element.append """<div class="section-now-playing"></div>"""

      list.append element

    list.parent().trigger('create')
    setSelectSectionEvent list
    list.show()


  bookmarks: (book, view) ->
    # Create an ordered list wrapper for the list
    view.children().remove()
    list = $('<ol data-role="listview" data-split-theme="d" data-split-icon="more_icn"></ol>').hide()
    view.append list
    list.attr 'data-title', book.title
    list.attr 'data-author', book.author
    list.attr 'data-totalTime', book.totalTime
    #list.attr 'id', 'NccRootElement'

    generateMoreItem = (bookmark, index) ->
      more = $('<a class="subsection" href="#">Mere</a>')
      more.on 'click', ->
        listItem = more.parents 'li'
        list.find('.bookmark-actions').remove()
        list.find('.bookmark-indents').remove()
        list.find('.active').removeClass('active')
        listItem.addClass 'active'
        remove = $('<div class="ui-block-b bookmark-delete" title="Slet" data-role="button" role="button">&nbsp;</div>')
        remove.on 'click', ->
          book.bookmarks.splice index, 1
          book.saveBookmarks()
          LYT.render.bookmarks book, view
        actionsItem = $('<ul class="bookmark-indents"><li class="bookmark-actions"><div class="ui-grid-a"></div></li></ul>')
        actionsItem.find('div').append(remove)
        listItem.after actionsItem
        list.listview('refresh')
      return more

    # if book.bookmarks is empty -> display message
    if book.bookmarks.length is 0
      element = jQuery '<li></li>'
      element.append LYT.i18n('No bookmarks defined yet')
      list.append element
    else
      for bookmark, index in book.bookmarks
        element = jQuery '<li></li>'
        element.attr 'id', bookmark.id
        element.attr 'data-href', bookmark.id
        [baseUrl, id] = bookmark.URI.split('#')
        element.append """
            <a class="gatrack section-link" data-ga-action="Link" data-ga-book-id="#{book.id}"
               data-book=\"#{book.id}\" data-smil=\"#{baseUrl}\" data-segment=\"#{id}\"
               data-offset=\"#{LYT.utils.formatTime bookmark.timeOffset}\"
               href="#book-player?book=#{book.id}">
              #{bookmark.note?.text or bookmark.timeOffset}
            </a>
          """
        element.append generateMoreItem(bookmark, index)
        list.append element

    list.parent().trigger('create')
    setSelectSectionEvent list
    list.show()

  setHeader: (page, text) ->
    header = $(page).children(':jqmData(role=header)').find('h1')
    header.text LYT.i18n text

  setPageTitle: (title) ->
    document.title = "#{title} | #{LYT.i18n('Sitename')}"

  showDialog: (parent, parameters) ->
    LYT.loader.clear()
    parent.simpledialog parameters

    # simpleDialog does not have aria labels on the output elements, so screenreaders has
    # no chance of finding out what the dialog is saying without going into advanced
    # formular or cursor modes (usually not used by not-so-advanced users)
    #
    # Modify the created ui-simpledialog-container so that the screenreader knows this is an alert
    $('.ui-simpledialog-container').attr 'role', 'alert'
    $('.ui-simpledialog-header h4').attr 'role', 'alert'
    $('.ui-simpledialog-subtitle').attr 'role', 'alert'

  showTestTab: -> $('.test-tab').show()

  hideTestTab: -> $('.test-tab').hide()
