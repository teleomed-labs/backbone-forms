###*
# NUMBER
# 
# Normal text input that only allows a number. Letters etc. are not entered.
###

Form.editors.Number = Form.editors.Text.extend(
  defaultValue: 0
  events: _.extend({}, Form.editors.Text::events,
    'keypress': 'onKeyPress'
    'change': 'onKeyPress')
  initialize: (options) ->
    Form.editors.Text::initialize.call this, options
    schema = @schema
    @$el.attr 'type', 'number'
    if !schema or !schema.editorAttrs or !schema.editorAttrs.step
      # provide a default for `step` attr,
      # but don't overwrite if already specified
      @$el.attr 'step', 'any'
    return
  onKeyPress: (event) ->
    self = this

    delayedDetermineChange = ->
      setTimeout (->
        self.determineChange()
        return
      ), 0
      return

    #Allow backspace
    if event.charCode == 0
      delayedDetermineChange()
      return
    #Get the whole new value so that we can prevent things like double decimals points etc.
    newVal = @$el.val()
    if event.charCode != undefined
      newVal = newVal + String.fromCharCode(event.charCode)
    numeric = /^[0-9]*\.?[0-9]*?$/.test(newVal)
    if numeric
      delayedDetermineChange()
    else
      event.preventDefault()
    return
  getValue: ->
    value = @$el.val()
    if value == '' then null else parseFloat(value, 10)
  setValue: (value) ->
    value = do ->
      if _.isNumber(value)
        return value
      if _.isString(value) and value != ''
        return parseFloat(value, 10)
      null
    if _.isNaN(value)
      value = null
    @value = value
    Form.editors.Text::setValue.call this, value
    return
)
