# Higher-level functions for interacting with the server 

# FIXME: Check for errors and attempt re-login etc.

# ## Faults (cf. [Daisy specification](http://www.daisy.org/projects/daisy-online-delivery/drafts/20100402/do-spec-20100402.html#apiReferenceFaults))
window.SERVICE_INTERNAL_ERROR       = "internalServerError"
window.SERVICE_NO_SESSION_ERROR     = "noActiveSession"
window.SERVICE_UNSUPPORTED_OP_ERROR = "operationNotSupported"
window.SERVICE_INVALID_OP_ERROR     = "invalidOperation"
window.SERVICE_INVALID_PARAM_ERROR  = "invalidParameter"


LYT.service =
  # Perform the logOn handshake:
  # logOn -> getServiceAttributes -> setReadingSystemAttributes
  logOn: (username, password) ->
    deferred = jQuery.Deferred()
    operations = null
    
    # For readability, the handlers are separated out here
    failed = (code, message) ->
      deferred.reject code, message
      
    loggedOn = (success) ->
      LYT.rpc("getServiceAttributes")
        .done(gotServiceAttrs)
        .fail(failed)
    
    gotServiceAttrs = (ops) ->
      operations = ops
      LYT.rpc("setReadingSystemAttributes")
        .done(readingSystemAttrsSet)
        .fail(failed)
    
    readingSystemAttrsSet = ->
      deferred.resolve()
      
      # TODO: If there are service announcements, do they have to be
      # retrieved before the handshake is considered done?
      if operations.indexOf("SERVICE_ANNOUNCEMENTS") isnt -1
        LYT.rpc("getServiceAnnouncements")
          .done(gotServiceAnnouncements)
          # Fail silently
    
    # FIXME: Not implemented
    gotServiceAnnouncements = (announcements) ->
    
    # Kick it off
    LYT.rpc("logOn", username, password)
      .done(loggedOn)
      .fail(failed)
    
    return deferred
  
  
  # TODO: Can logOff fail? If so, what to do?
  logOff: ->
    LYT.rpc("logOff")
  
  
  issue: (bookId) ->
    LYT.rpc "issueContent", bookId
  
  
  return: (bookId) ->
    LYT.rpc "returnContent", bookId
  
  
  getMetadata: (bookId) ->
    LYT.rpc "getContentMetadata", bookId
  
  
  getResources: (bookId) ->
    LYT.rpc "getContentResources", bookId
  
  
  getBookshelf: (from = 0, to = -1) ->
    deferred = jQuery.Deferred()
    LYT.rpc("getContentList", "issued", from, to)
      .then (list) ->
        for item in list
          # TODO: Using $ as a make-shift delimiter in XML? Instead of y'know using... more XML? Wow.  
          # To quote [Nokogiri](http://nokogiri.org/): "XML is like violence - if it doesn’t solve your problems, you are not using enough of it."
          [item.author, item.title] = item.label?.split("$") or ["", ""]
          delete item.label
        deferred.resolve list
      .fail -> deferred.reject()
    deferred
  
  
  # Non-Daisy function
  search: (query) ->
  
  
  
