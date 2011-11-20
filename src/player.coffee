# This module handles playback of current media and timing of transcript updates

LYT.player =
  
  ready: false 
  el: null
  media: null #id, start, end, text
  section: null
  time: ""
  book: null #reference to an instance of book class
  
  # todo: consider array of all played sections and a few following
  
  
  setup: ->
    # Initialize jplayer and set ready True when ready
    @el = jQuery("#jplayer")
    jplayer = @el.jPlayer
      ready: =>
        @ready = true
        
        @el.bind jQuery.jPlayer.event.timeupdate, (event) =>
          @updateText(event.jPlayer.status.currentTime)
        
        @el.bind jQuery.jPlayer.event.ended, (event) =>
          @updateText(event.jPlayer.status.currentTime)
        
        null
      
      swfPath: "./lib/jPlayer/"
      supplied: "mp3"
      solution: 'html, flash'
    
    @ready
    
  pause: ->
    # Pause current media
    @el.jPlayer('pause')
    
    null
  
  stop: ->
    # Stop playing and stop downloading current media file
    @el.jPlayer('stop')
    @el.jPlayer('clearMedia')
    
    'stopped'
  
  play: (time) ->
    # Start or resume playing if media is loaded
    # Starts playing at time seconds if specified, else from 
    # when media was paused, else from the beginning.
    if not time?
      @el.jPlayer('play')
    else
      @el.jPlayer('play', time)
    
    'playing'
  
  updateText: (time) ->
    # Continously update media for current time of section
    @time = time
    if @media.end < @time
      #log.message('current media has ended at ' + @media.end + ' getting new media for ' + @time ) 
      @book.mediaFor(@section.id,@time).done (media) =>
        if media
          @media = media
          jQuery("#book-text-content").html("<p id='#{@media.id}'>#{@media.text}</p>")
        else
          log.message 'failed to get media'
    
    #if @media.end < @time
    #  #LYT.gui.hideTranscript("")
    #  log.message(@media.end + ' is less than ' + @time)
    #  log.message('Hide:' + @media.text)
      
    #else if @media.start >= @time
    #  log.message(@media.start + ' is more than ' + @time)
    #  #LYT.gui.updateTranscript("")
    #  #LYT.gui.showTranscript("")
    #  log.message('Show:' + @media.text)
     
  loadBook: (book, section, offset) ->
    @book = book
    # select section or take first off book.sections
    
    @section = section
    
    @book.mediaFor(@section.id,0).done (media) =>
      log.message media
      if media
        @media = media
        @el.jPlayer('setMedia', {mp3: media.audio})
        jQuery("#book-text-content").html("<p id='#{@media.id}'>#{@media.text}</p>")
        @play()
      else
        log.message 'could not get media'
    
      
  nextPart: () ->
    @stop()
    # get next part
    @load()
    
  previousPart: () ->
    @stop()
    # get next part
    @load()
     

  