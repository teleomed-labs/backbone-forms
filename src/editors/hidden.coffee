###*
# Hidden editor
###

Form.editors.Hidden = Form.editors.Text.extend(
  defaultValue: ''
  noField: true
  initialize: (options) ->
    Form.editors.Text::initialize.call this, options
    @$el.attr 'type', 'hidden'
    return
  focus: ->
  blur: ->
)
