###*
# TextArea editor
###

Form.editors.TextArea = Form.editors.Text.extend(
  tagName: 'textarea'
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    return
)
