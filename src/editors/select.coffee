###*
# Select editor
#
# Renders a <select> with given options
#
# Requires an 'options' value on the schema.
#  Can be an array of options, a function that calls back with the array of options, a string of HTML
#  or a Backbone collection. If a collection, the models must implement a toString() method
###

Form.editors.Select = Form.editors.Base.extend(
  tagName: 'select'
  previousValue: ''
  events:
    'keyup': 'determineChange'
    'keypress': (event) ->
      self = this
      setTimeout (->
        self.determineChange()
        return
      ), 0
      return
    'change': (event) ->
      @trigger 'change', this
      return
    'focus': (event) ->
      @trigger 'focus', this
      return
    'blur': (event) ->
      @trigger 'blur', this
      return
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    if !@schema or !@schema.options
      throw new Error('Missing required \'schema.options\'')
    return
  render: ->
    @setOptions @schema.options
    this
  setOptions: (options) ->
    self = this
    #If a collection was passed, check if it needs fetching
    if options instanceof Backbone.Collection
      collection = options
      #Don't do the fetch if it's already populated
      if collection.length > 0
        @renderOptions options
      else
        collection.fetch success: (collection) ->
          self.renderOptions options
          return
    else if _.isFunction(options)
      options ((result) ->
        self.renderOptions result
        return
      ), self
    else
      @renderOptions options
    return
  renderOptions: (options) ->
    $select = @$el
    html = undefined
    html = @_getOptionsHtml(options)
    #Insert options
    $select.html html
    #Select correct option
    @setValue @value
    return
  _getOptionsHtml: (options) ->
    html = undefined
    #Accept string of HTML
    if _.isString(options)
      html = options
    else if _.isArray(options)
      html = @_arrayToHtml(options)
    else if options instanceof Backbone.Collection
      html = @_collectionToHtml(options)
    else if _.isFunction(options)
      newOptions = undefined
      options ((opts) ->
        newOptions = opts
        return
      ), this
      html = @_getOptionsHtml(newOptions)
      #Or any object
    else
      html = @_objectToHtml(options)
    html
  determineChange: (event) ->
    currentValue = @getValue()
    changed = currentValue != @previousValue
    if changed
      @previousValue = currentValue
      @trigger 'change', this
    return
  getValue: ->
    @$el.val()
  setValue: (value) ->
    # Set value to the first option if no valid value is provided.
    if not value? and not @value
      value = @$('option').first().val()

    @value = value
    @$el.val value
    return
  focus: ->
    if @hasFocus
      return
    @$el.focus()
    return
  blur: ->
    if !@hasFocus
      return
    @$el.blur()
    return
  _collectionToHtml: (collection) ->
    #Convert collection to array first
    array = []
    collection.each (model) ->
      array.push
        val: model.id
        label: model.toString()
      return
    #Now convert to HTML
    html = @_arrayToHtml(array)
    html
  _objectToHtml: (obj) ->
    #Convert object to array first
    array = []
    for key of obj
      if obj.hasOwnProperty(key)
        array.push
          val: key
          label: obj[key]
    #Now convert to HTML
    html = @_arrayToHtml(array)
    html
  _arrayToHtml: (array) ->
    html = $()
    #Generate HTML
    _.each array, ((option) ->
      if _.isObject(option)
        if option.group
          optgroup = $('<optgroup>').attr('label', option.group).html(@_getOptionsHtml(option.options))
          html = html.add(optgroup)
        else
          val = if option.val or option.val == 0 then option.val else ''
          html = html.add($('<option>').val(val).text(option.label))
      else
        html = html.add($('<option>').text(option))
      return
    ), this
    html
)
