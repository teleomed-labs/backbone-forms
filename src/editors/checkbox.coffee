###*
# Checkbox editor
#
# Creates a single checkbox, i.e. boolean value
###

Form.editors.Checkbox = Form.editors.Base.extend(
  defaultValue: false
  tagName: 'input'
  events:
    'click': (event) ->
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
    @$el.attr 'type', 'checkbox'
    return
  render: ->
    @setValue @value
    this
  getValue: ->
    @$el.prop 'checked'
  setValue: (value) ->
    if value
      @$el.prop 'checked', true
    else
      @$el.prop 'checked', false
    @value = ! !value
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
)
