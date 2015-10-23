###*
# Password editor
###

Form.editors.Password = Form.editors.Text.extend(initialize: (options) ->
  Form.editors.Text::initialize.call this, options
  @$el.attr 'type', 'password'
  return
)
