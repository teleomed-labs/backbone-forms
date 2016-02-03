###*
# DateTime editor
#
# @param {Editor} [options.DateEditor]           Date editor view to use (not definition)
# @param {Number} [options.schema.minsInterval]  Interval between minutes. Default: 15
###

Form.editors.DateTime = Form.editors.Base.extend({
  events:
    'change select': ->
      @updateHidden()
      @trigger 'change', this
      return
    'focus select': ->
      if @hasFocus
        return
      @trigger 'focus', this
      return
    'blur select': ->
      if !@hasFocus
        return
      self = this
      setTimeout (->
        if self.$('select:focus')[0]
          return
        self.trigger 'blur', self
        return
      ), 0
      return
  initialize: (options) ->
    options = options or {}
    Form.editors.Base::initialize.call this, options
    #Option defaults
    @options = _.extend({ DateEditor: Form.editors.DateTime.DateEditor }, options)
    #Schema defaults
    @schema = _.extend({ minsInterval: 15 }, options.schema or {})
    #Create embedded date editor
    @dateEditor = new (@options.DateEditor)(options)
    @value = @dateEditor.value
    #Template
    @template = options.template or @constructor.template
    return
  render: ->
    pad = (n) ->
      if n < 10 then '0' + n else n

    schema = @schema
    $ = Backbone.$
    #Create options
    hoursOptions = _.map(_.range(0, 24), (hour) ->
      '<option value="' + hour + '">' + pad(hour) + '</option>'
    )
    minsOptions = _.map(_.range(0, 60, schema.minsInterval), (min) ->
      '<option value="' + min + '">' + pad(min) + '</option>'
    )
    #Render time selects
    $el = $($.trim(@template(
      hours: hoursOptions.join()
      mins: minsOptions.join())))
    #Include the date editor

    $el.find('[data-date]').append @dateEditor.render().el
    #Store references to selects
    @$hour = $el.find('select[data-type="hour"]')
    @$min = $el.find('select[data-type="min"]')
    #Get the hidden date field to store values in case POSTed to server
    @$hidden = $el.find('input[type="hidden"]')
    #Set time
    @setValue @value
    @setElement $el
    @$el.attr 'id', @id
    @$el.attr 'name', @getName()
    if @hasFocus
      @trigger 'blur', this
    this
  getValue: ->
    date = @dateEditor.getValue()
    hour = @$hour.val()
    min = @$min.val()
    if !date or !hour or !min
      return null
    date.setHours hour
    date.setMinutes min
    date
  setValue: (date) ->
    if !_.isDate(date)
      date = new Date(date)
    @value = date
    @dateEditor.setValue date
    @$hour.val date.getHours()
    @$min.val date.getMinutes()
    @updateHidden()
    return
  focus: ->
    if @hasFocus
      return
    @$('select').first().focus()
    return
  blur: ->
    if !@hasFocus
      return
    @$('select:focus').blur()
    return
  updateHidden: ->
    val = @getValue()
    if _.isDate(val)
      val = val.toISOString()
    @$hidden.val val
    return
  remove: ->
    @dateEditor.remove()
    Form.editors.Base::remove.call this
    return

},
  template: _.template('    <div class="bbf-datetime">      <div class="bbf-date-container" data-date></div>      <select data-type="hour"><%= hours %></select>      :      <select data-type="min"><%= mins %></select>    </div>  ', null, Form.templateSettings)
  DateEditor: Form.editors.Date)
