###*
# Checkboxes editor
#
# Renders a <ul> with given options represented as <li> objects containing checkboxes
#
# Requires an 'options' value on the schema.
#  Can be an array of options, a function that calls back with the array of options, a string of HTML
#  or a Backbone collection. If a collection, the models must implement a toString() method
###

Form.editors.Checkboxes = Form.editors.Select.extend(
  tagName: 'ul'
  groupNumber: 0
  events:
    'click input[type=checkbox]': ->
      @trigger 'change', this
      return
    'focus input[type=checkbox]': ->
      if @hasFocus
        return
      @trigger 'focus', this
      return
    'blur input[type=checkbox]': ->
      if !@hasFocus
        return
      self = this
      setTimeout (->
        if self.$('input[type=checkbox]:focus')[0]
          return
        self.trigger 'blur', self
        return
      ), 0
      return
  getValue: ->
    values = []
    @$('input[type=checkbox]:checked').each ->
      values.push $(this).val()
      return
    values
  setValue: (values) ->
    if !_.isArray(values)
      values = [ values ]
    @value = values
    @$('input[type=checkbox]').val values
    return
  focus: ->
    if @hasFocus
      return
    @$('input[type=checkbox]').first().focus()
    return
  blur: ->
    if !@hasFocus
      return
    @$('input[type=checkbox]:focus').blur()
    return
  _arrayToHtml: (array) ->
    html = $()
    self = this
    _.each array, (option, index) ->
      itemHtml = $('<li>')
      if _.isObject(option)
        if option.group
          originalId = self.id
          self.id += '-' + self.groupNumber++
          itemHtml = $('<fieldset class="group">').append($('<legend>').text(option.group))
          itemHtml = itemHtml.append(self._arrayToHtml(option.options))
          self.id = originalId
          close = false
        else
          val = if option.val or option.val == 0 then option.val else ''
          itemHtml.append $('<input type="checkbox" name="' + self.getName() + '" id="' + self.id + '-' + index + '" />').val(val)
          if option.labelHTML
            itemHtml.append $('<label for="' + self.id + '-' + index + '">').html(option.labelHTML)
          else
            itemHtml.append $('<label for="' + self.id + '-' + index + '">').text(option.label)
      else
        itemHtml.append $('<input type="checkbox" name="' + self.getName() + '" id="' + self.id + '-' + index + '" />').val(option)
        itemHtml.append $('<label for="' + self.id + '-' + index + '">').text(option)
      html = html.add(itemHtml)
      return
    html
)
