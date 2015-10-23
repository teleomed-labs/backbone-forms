###*
# Date editor
#
# Schema options
# @param {Number|String} [options.schema.yearStart]  First year in list. Default: 100 years ago
# @param {Number|String} [options.schema.yearEnd]    Last year in list. Default: current year
#
# Config options (if not set, defaults to options stored on the main Date class)
# @param {Boolean} [options.showMonthNames]  Use month names instead of numbers. Default: true
# @param {String[]} [options.monthNames]     Month names. Default: Full English names
###

Form.editors.Date = Form.editors.Base.extend({
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
    Self = Form.editors.Date
    today = new Date
    #Option defaults
    @options = _.extend({
      monthNames: Self.monthNames
      showMonthNames: Self.showMonthNames
    }, options)
    #Schema defaults
    @schema = _.extend({
      yearStart: today.getFullYear() - 100
      yearEnd: today.getFullYear()
    }, options.schema or {})
    #Cast to Date
    if @value and !_.isDate(@value)
      @value = new Date(@value)
    #Set default date
    if !@value
      date = new Date
      date.setSeconds 0
      date.setMilliseconds 0
      @value = date
    #Template
    @template = options.template or @constructor.template
    return
  render: ->
    options = @options
    schema = @schema
    $ = Backbone.$
    datesOptions = _.map(_.range(1, 32), (date) ->
      '<option value="' + date + '">' + date + '</option>'
    )
    monthsOptions = _.map(_.range(0, 12), (month) ->
      value = if options.showMonthNames then options.monthNames[month] else month + 1
      '<option value="' + month + '">' + value + '</option>'
    )
    yearRange = if schema.yearStart < schema.yearEnd then _.range(schema.yearStart, schema.yearEnd + 1) else _.range(schema.yearStart, schema.yearEnd - 1, -1)
    yearsOptions = _.map(yearRange, (year) ->
      '<option value="' + year + '">' + year + '</option>'
    )
    #Render the selects
    $el = $($.trim(@template(
      dates: datesOptions.join('')
      months: monthsOptions.join('')
      years: yearsOptions.join(''))))
    #Store references to selects
    @$date = $el.find('[data-type="date"]')
    @$month = $el.find('[data-type="month"]')
    @$year = $el.find('[data-type="year"]')
    #Create the hidden field to store values in case POSTed to server
    @$hidden = $('<input type="hidden" name="' + @key + '" />')
    $el.append @$hidden
    #Set value on this and hidden field
    @setValue @value
    #Remove the wrapper tag
    @setElement $el
    @$el.attr 'id', @id
    @$el.attr 'name', @getName()
    if @hasFocus
      @trigger 'blur', this
    this
  getValue: ->
    year = @$year.val()
    month = @$month.val()
    date = @$date.val()
    if !year or !month or !date
      return null
    new Date(year, month, date)
  setValue: (date) ->
    @value = date
    @$date.val date.getDate()
    @$month.val date.getMonth()
    @$year.val date.getFullYear()
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

},
  template: _.template('    <div>      <select data-type="date"><%= dates %></select>      <select data-type="month"><%= months %></select>      <select data-type="year"><%= years %></select>    </div>  ', null, Form.templateSettings)
  showMonthNames: true
  monthNames: [
    'January'
    'February'
    'March'
    'April'
    'May'
    'June'
    'July'
    'August'
    'September'
    'October'
    'November'
    'December'
  ])
