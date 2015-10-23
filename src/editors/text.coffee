###*
# Text
# 
# Text input with focus, blur and change events
###

Form.editors.Text = Form.Editor.extend(
  tagName: 'input'
  defaultValue: ''
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
    'select': (event) ->
      @trigger 'select', this
      return
    'focus': (event) ->
      @trigger 'focus', this
      return
    'blur': (event) ->
      @trigger 'blur', this
      return
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    schema = @schema
    #Allow customising text type (email, phone etc.) for HTML5 browsers
    type = 'text'
    if schema and schema.editorAttrs and schema.editorAttrs.type
      type = schema.editorAttrs.type
    if schema and schema.dataType
      type = schema.dataType
    @$el.attr 'type', type
    return
  render: ->
    @setValue @value
    this
  determineChange: (event) ->
    currentValue = @$el.val()
    changed = currentValue != @previousValue
    if changed
      @previousValue = currentValue
      @trigger 'change', this
    return
  getValue: ->
    @$el.val()
  setValue: (value) ->
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
  select: ->
    @$el.select()
    return
)
