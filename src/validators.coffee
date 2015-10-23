#==================================================================================================
#VALIDATORS
#==================================================================================================
Form.validators = do ->
  validators = {}
  validators.errMessages =
    required: 'Required'
    regexp: 'Invalid'
    number: 'Must be a number'
    email: 'Invalid email address'
    url: 'Invalid URL'
    match: _.template('Must match field "<%= field %>"', null, Form.templateSettings)

  validators.required = (options) ->
    options = _.extend({
      type: 'required'
      message: @errMessages.required
    }, options)
    (value) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      if value == null or value == undefined or value == false or value == ''
        return err
      return

  validators.regexp = (options) ->
    if !options.regexp
      throw new Error('Missing required "regexp" option for "regexp" validator')
    options = _.extend({
      type: 'regexp'
      match: true
      message: @errMessages.regexp
    }, options)
    (value) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      #Don't check empty values (add a 'required' validator for this)
      if value == null or value == undefined or value == ''
        return
      #Create RegExp from string if it's valid
      if 'string' == typeof options.regexp
        options.regexp = new RegExp(options.regexp, options.flags)
      if (if options.match then !options.regexp.test(value) else options.regexp.test(value))
        return err
      return

  validators.number = (options) ->
    options = _.extend({
      type: 'number'
      message: @errMessages.number
      regexp: /^[0-9]*\.?[0-9]*?$/
    }, options)
    validators.regexp options

  validators.email = (options) ->
    options = _.extend({
      type: 'email'
      message: @errMessages.email
      regexp: /^[\w\-]{1,}([\w\-\+.]{1,1}[\w\-]{1,}){0,}[@][\w\-]{1,}([.]([\w\-]{1,})){1,3}$/
    }, options)
    validators.regexp options

  validators.url = (options) ->
    options = _.extend({
      type: 'url'
      message: @errMessages.url
      regexp: /^(http|https):\/\/(([A-Z0-9][A-Z0-9_\-]*)(\.[A-Z0-9][A-Z0-9_\-]*)+)(:(\d+))?\/?/i
    }, options)
    validators.regexp options

  validators.match = (options) ->
    if !options.field
      throw new Error('Missing required "field" options for "match" validator')
    options = _.extend({
      type: 'match'
      message: @errMessages.match
    }, options)
    (value, attrs) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      #Don't check empty values (add a 'required' validator for this)
      if value == null or value == undefined or value == ''
        return
      if value != attrs[options.field]
        return err
      return

  validators
