###*
# Radio editor
#
# Renders a <ul> with given options represented as <li> objects containing radio buttons
#
# Requires an 'options' value on the schema.
#  Can be an array of options, a function that calls back with the array of options, a string of HTML
#  or a Backbone collection. If a collection, the models must implement a toString() method
###

Form.editors.Radio = Form.editors.Select.extend({
  tagName: 'ul'
  events:
    'change input[type=radio]': ->
      @trigger 'change', this
      return
    'focus input[type=radio]': ->
      if @hasFocus
        return
      @trigger 'focus', this
      return
    'blur input[type=radio]': ->
      if !@hasFocus
        return
      self = this
      setTimeout (->
        if self.$('input[type=radio]:focus')[0]
          return
        self.trigger 'blur', self
        return
      ), 0
      return
  getTemplate: ->
    @schema.template or @constructor.template
  getValue: ->
    @$('input[type=radio]:checked').val()
  setValue: (value) ->
    # Set a default value if defined on the schema.
    if not value? and @schema.default?
      value = @schema.default

    @value = value
    @$('input[type=radio]').val [ value ]
    return
  focus: ->
    if @hasFocus
      return
    checked = @$('input[type=radio]:checked')
    if checked[0]
      checked.focus()
      return
    @$('input[type=radio]').first().focus()
    return
  blur: ->
    if !@hasFocus
      return
    @$('input[type=radio]:focus').blur()
    return
  _arrayToHtml: (array) ->
    self = this
    template = @getTemplate()
    name = self.getName()
    id = self.id
    items = _.map(array, (option, index) ->
      item = 
        name: name
        id: id + '-' + index
      if _.isObject(option)
        item.value = if option.val or option.val == 0 then option.val else ''
        item.label = option.label
        item.labelHTML = option.labelHTML
      else
        item.value = option
        item.label = option
      item
    )
    template items: items

}, template: _.template('    <% _.each(items, function(item) { %>      <li>        <input type="radio" name="<%= item.name %>" value="<%- item.value %>" id="<%= item.id %>" />        <label for="<%= item.id %>"><% if (item.labelHTML){ %><%= item.labelHTML %><% }else{ %><%- item.label %><% } %></label>      </li>    <% }); %>  ', null, Form.templateSettings))
