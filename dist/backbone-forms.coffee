#==================================================================================================
#FORM
#==================================================================================================
Form = Backbone.View.extend({
  events: 'submit': (event) ->
    @trigger 'submit', event
    return
  initialize: (options) ->
    self = this
    #Merge default options
    options = @options = _.extend({ submitButton: false }, options)
    #Find the schema to use
    schema = @schema = do ->
      #Prefer schema from options
      if options.schema
        return _.result(options, 'schema')
      #Then schema on model
      model = options.model
      if model and model.schema
        return _.result(model, 'schema')
      #Then built-in schema
      if self.schema
        return _.result(self, 'schema')
      #Fallback to empty schema
      {}
    #Store important data
    _.extend this, _.pick(options, 'model', 'data', 'idPrefix', 'templateData')
    #Override defaults
    constructor = @constructor
    @template = options.template or @template or constructor.template
    @Fieldset = options.Fieldset or @Fieldset or constructor.Fieldset
    @Field = options.Field or @Field or constructor.Field
    @NestedField = options.NestedField or @NestedField or constructor.NestedField
    #Check which fields will be included (defaults to all)
    selectedFields = @selectedFields = options.fields or _.keys(schema)
    #Create fields
    fields = @fields = {}
    _.each selectedFields, ((key) ->
      fieldSchema = schema[key]
      fields[key] = @createField(key, fieldSchema)
      return
    ), this
    #Create fieldsets
    fieldsetSchema = options.fieldsets or _.result(this, 'fieldsets') or _.result(@model, 'fieldsets') or [ selectedFields ]
    fieldsets = @fieldsets = []
    _.each fieldsetSchema, ((itemSchema) ->
      @fieldsets.push @createFieldset(itemSchema)
      return
    ), this
    return
  createFieldset: (schema) ->
    options = 
      schema: schema
      fields: @fields
      legend: schema.legend or null
    new (@Fieldset)(options)
  createField: (key, schema) ->
    options = 
      form: this
      key: key
      schema: schema
      idPrefix: @idPrefix
    if @model
      options.model = @model
    else if @data
      options.value = @data[key]
    else
      options.value = null
    field = new (@Field)(options)
    @listenTo field.editor, 'all', @handleEditorEvent
    field
  handleEditorEvent: (event, editor) ->
    #Re-trigger editor events on the form
    formEvent = editor.key + ':' + event
    @trigger.call this, formEvent, this, editor, Array::slice.call(arguments, 2)
    #Trigger additional events
    switch event
      when 'change'
        @trigger 'change', this
      when 'focus'
        if !@hasFocus
          @trigger 'focus', this
      when 'blur'
        if @hasFocus
          #TODO: Is the timeout etc needed?
          self = this
          setTimeout (->
            focusedField = _.find(self.fields, (field) ->
              field.editor.hasFocus
            )
            if !focusedField
              self.trigger 'blur', self
            return
          ), 0
    return
  templateData: ->
    options = @options
    { submitButton: options.submitButton }
  render: ->
    self = this
    fields = @fields
    $ = Backbone.$
    #Render form
    $form = $($.trim(@template(_.result(this, 'templateData'))))
    #Render standalone editors
    $form.find('[data-editors]').add($form).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-editors')
      if _.isUndefined(selection)
        return
      #Work out which fields to include
      keys = if selection == '*' then self.selectedFields or _.keys(fields) else selection.split(',')
      #Add them
      _.each keys, (key) ->
        field = fields[key]
        $container.append field.editor.render().el
        return
      return
    #Render standalone fields
    $form.find('[data-fields]').add($form).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-fields')
      if _.isUndefined(selection)
        return
      #Work out which fields to include
      keys = if selection == '*' then self.selectedFields or _.keys(fields) else selection.split(',')
      #Add them
      _.each keys, (key) ->
        field = fields[key]
        $container.append field.render().el
        return
      return
    #Render fieldsets
    $form.find('[data-fieldsets]').add($form).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-fieldsets')
      if _.isUndefined(selection)
        return
      _.each self.fieldsets, (fieldset) ->
        $container.append fieldset.render().el
        return
      return
    #Set the main element
    @setElement $form
    #Set class
    $form.addClass @className
    this
  validate: (options) ->
    self = this
    fields = @fields
    model = @model
    errors = {}
    options = options or {}
    #Collect errors from schema validation
    _.each fields, (field) ->
      error = field.validate()
      if error
        errors[field.key] = error
      return
    #Get errors from default Backbone model validator
    if !options.skipModelValidate and model and model.validate
      modelErrors = model.validate(@getValue())
      if modelErrors
        isDictionary = _.isObject(modelErrors) and !_.isArray(modelErrors)
        #If errors are not in object form then just store on the error object
        if !isDictionary
          errors._others = errors._others or []
          errors._others.push modelErrors
        #Merge programmatic errors (requires model.validate() to return an object e.g. { fieldKey: 'error' })
        if isDictionary
          _.each modelErrors, (val, key) ->
            #Set error on field if there isn't one already
            if fields[key] and !errors[key]
              fields[key].setError val
              errors[key] = val
            else
              #Otherwise add to '_others' key
              errors._others = errors._others or []
              tmpErr = {}
              tmpErr[key] = val
              errors._others.push tmpErr
            return
    if _.isEmpty(errors) then null else errors
  commit: (options) ->
    #Validate
    options = options or {}
    validateOptions = skipModelValidate: !options.validate
    errors = @validate(validateOptions)
    if errors
      return errors
    #Commit
    modelError = undefined
    setOptions = _.extend({ error: (model, e) ->
      modelError = e
      return
 }, options)
    @model.set @getValue(), setOptions
    if modelError
      return modelError
    return
  getValue: (key) ->
    #Return only given key if specified
    if key
      return @fields[key].getValue()
    #Otherwise return entire form
    values = {}
    _.each @fields, (field) ->
      values[field.key] = field.getValue()
      return
    values
  setValue: (prop, val) ->
    data = {}
    if typeof prop == 'string'
      data[prop] = val
    else
      data = prop
    key = undefined
    for key of @schema
      `key = key`
      if data[key] != undefined
        @fields[key].setValue data[key]
    return
  getEditor: (key) ->
    field = @fields[key]
    if !field
      throw new Error('Field not found: ' + key)
    field.editor
  focus: ->
    if @hasFocus
      return
    #Get the first field
    fieldset = @fieldsets[0]
    field = fieldset.getFieldAt(0)
    if !field
      return
    #Set focus
    field.editor.focus()
    return
  blur: ->
    if !@hasFocus
      return
    focusedField = _.find(@fields, (field) ->
      field.editor.hasFocus
    )
    if focusedField
      focusedField.editor.blur()
    return
  trigger: (event) ->
    if event == 'focus'
      @hasFocus = true
    else if event == 'blur'
      @hasFocus = false
    Backbone.View::trigger.apply this, arguments
  remove: ->
    _.each @fieldsets, (fieldset) ->
      fieldset.remove()
      return
    _.each @fields, (field) ->
      field.remove()
      return
    Backbone.View::remove.apply this, arguments

},
  template: _.template('    <form>     <div data-fieldsets></div>      <% if (submitButton) { %>        <button type="submit"><%= submitButton %></button>      <% } %>    </form>  ', null, @templateSettings)
  templateSettings:
    evaluate: /<%([\s\S]+?)%>/g
    interpolate: /<%=([\s\S]+?)%>/g
    escape: /<%-([\s\S]+?)%>/g
  editors: {})

Backbone.Form = Form

#==================================================================================================
#VALIDATORS
#==================================================================================================
Form.validators = do ->
  validators = {}
  validators.errMessages =
    required: 'Required'
    regexp: 'Invalid'
    number: 'Must be a number'
    email: 'Invalid email address'
    url: 'Invalid URL'
    match: _.template('Must match field "<%= field %>"', null, Form.templateSettings)

  validators.required = (options) ->
    options = _.extend({
      type: 'required'
      message: @errMessages.required
    }, options)
    (value) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      if value == null or value == undefined or value == false or value == ''
        return err
      return

  validators.regexp = (options) ->
    if !options.regexp
      throw new Error('Missing required "regexp" option for "regexp" validator')
    options = _.extend({
      type: 'regexp'
      match: true
      message: @errMessages.regexp
    }, options)
    (value) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      #Don't check empty values (add a 'required' validator for this)
      if value == null or value == undefined or value == ''
        return
      #Create RegExp from string if it's valid
      if 'string' == typeof options.regexp
        options.regexp = new RegExp(options.regexp, options.flags)
      if (if options.match then !options.regexp.test(value) else options.regexp.test(value))
        return err
      return

  validators.number = (options) ->
    options = _.extend({
      type: 'number'
      message: @errMessages.number
      regexp: /^[0-9]*\.?[0-9]*?$/
    }, options)
    validators.regexp options

  validators.email = (options) ->
    options = _.extend({
      type: 'email'
      message: @errMessages.email
      regexp: /^[\w\-]{1,}([\w\-\+.]{1,1}[\w\-]{1,}){0,}[@][\w\-]{1,}([.]([\w\-]{1,})){1,3}$/
    }, options)
    validators.regexp options

  validators.url = (options) ->
    options = _.extend({
      type: 'url'
      message: @errMessages.url
      regexp: /^(http|https):\/\/(([A-Z0-9][A-Z0-9_\-]*)(\.[A-Z0-9][A-Z0-9_\-]*)+)(:(\d+))?\/?/i
    }, options)
    validators.regexp options

  validators.match = (options) ->
    if !options.field
      throw new Error('Missing required "field" options for "match" validator')
    options = _.extend({
      type: 'match'
      message: @errMessages.match
    }, options)
    (value, attrs) ->
      options.value = value
      err = 
        type: options.type
        message: if _.isFunction(options.message) then options.message(options) else options.message
      #Don't check empty values (add a 'required' validator for this)
      if value == null or value == undefined or value == ''
        return
      if value != attrs[options.field]
        return err
      return

  validators

#==================================================================================================
#FIELDSET
#==================================================================================================
Form.Fieldset = Backbone.View.extend({
  initialize: (options) ->
    options = options or {}
    #Create the full fieldset schema, merging defaults etc.
    schema = @schema = @createSchema(options.schema)
    #Store the fields for this fieldset
    @fields = _.pick(options.fields, schema.fields)
    #Override defaults
    @template = options.template or schema.template or @template or @constructor.template
    return
  createSchema: (schema) ->
    #Normalise to object
    if _.isArray(schema)
      schema = fields: schema
    #Add null legend to prevent template error
    schema.legend = schema.legend or null
    schema
  getFieldAt: (index) ->
    key = @schema.fields[index]
    @fields[key]
  templateData: ->
    @schema
  render: ->
    schema = @schema
    fields = @fields
    $ = Backbone.$
    #Render fieldset
    $fieldset = $($.trim(@template(_.result(this, 'templateData'))))
    #Render fields
    $fieldset.find('[data-fields]').add($fieldset).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-fields')
      if _.isUndefined(selection)
        return
      _.each fields, (field) ->
        $container.append field.render().el
        return
      return
    @setElement $fieldset
    this
  remove: ->
    _.each @fields, (field) ->
      field.remove()
      return
    Backbone.View::remove.call this
    return

}, template: _.template('    <fieldset data-fields>      <% if (legend) { %>        <legend><%= legend %></legend>      <% } %>    </fieldset>  ', null, Form.templateSettings))

#==================================================================================================
#FIELD
#==================================================================================================
Form.Field = Backbone.View.extend({
  initialize: (options) ->
    options = options or {}
    #Store important data
    _.extend this, _.pick(options, 'form', 'key', 'model', 'value', 'idPrefix')
    #Create the full field schema, merging defaults etc.
    schema = @schema = @createSchema(options.schema)
    #Override defaults
    @template = options.template or schema.template or @template or @constructor.template
    @errorClassName = options.errorClassName or @errorClassName or @constructor.errorClassName
    #Create editor
    @editor = @createEditor()
    return
  createSchema: (schema) ->
    if _.isString(schema)
      schema = type: schema
    #Set defaults
    schema = _.extend({
      type: 'Text'
      title: @createTitle()
    }, schema)
    #Get the real constructor function i.e. if type is a string such as 'Text'
    schema.type = if _.isString(schema.type) then Form.editors[schema.type] else schema.type
    schema
  createEditor: ->
    options = _.extend(_.pick(this, 'schema', 'form', 'key', 'model', 'value'), id: @createEditorId())
    constructorFn = @schema.type
    new constructorFn(options)
  createEditorId: ->
    prefix = @idPrefix
    id = @key
    #Replace periods with underscores (e.g. for when using paths)
    id = id.replace(/\./g, '_')
    #If a specific ID prefix is set, use it
    if _.isString(prefix) or _.isNumber(prefix)
      return prefix + id
    if _.isNull(prefix)
      return id
    #Otherwise, if there is a model use it's CID to avoid conflicts when multiple forms are on the page
    if @model
      return @model.cid + '_' + id
    id
  createTitle: ->
    str = @key
    #Add spaces
    str = str.replace(/([A-Z])/g, ' $1')
    #Uppercase first character
    str = str.replace(/^./, (str) ->
      str.toUpperCase()
    )
    str
  templateData: ->
    schema = @schema
    {
      help: schema.help or ''
      title: schema.title
      titleHTML: schema.titleHTML
      fieldAttrs: schema.fieldAttrs
      editorAttrs: schema.editorAttrs
      key: @key
      editorId: @editor.id
    }
  render: ->
    schema = @schema
    editor = @editor
    $ = Backbone.$
    #Only render the editor if requested
    if @editor.noField == true
      return @setElement(editor.render().el)
    #Render field
    $field = $($.trim(@template(_.result(this, 'templateData'))))
    if schema.fieldClass
      $field.addClass schema.fieldClass
    if schema.fieldAttrs
      $field.attr schema.fieldAttrs
    #Render editor
    $field.find('[data-editor]').add($field).each (i, el) ->
      $container = $(el)
      selection = $container.attr('data-editor')
      if _.isUndefined(selection)
        return
      $container.append editor.render().el
      return
    @setElement $field
    this
  disable: ->
    if _.isFunction(@editor.disable)
      @editor.disable()
    else
      $input = @editor.$el
      $input = if $input.is('input') then $input else $input.find('input')
      $input.attr 'disabled', true
    return
  enable: ->
    if _.isFunction(@editor.enable)
      @editor.enable()
    else
      $input = @editor.$el
      $input = if $input.is('input') then $input else $input.find('input')
      $input.attr 'disabled', false
    return
  validate: ->
    error = @editor.validate()
    if error
      @setError error.message
    else
      @clearError()
    error
  setError: (msg) ->
    #Nested form editors (e.g. Object) set their errors internally
    if @editor.hasNestedForm
      return
    #Add error CSS class
    @$el.addClass @errorClassName
    #Set error message
    @$('[data-error]').html msg
    return
  clearError: ->
    #Remove error CSS class
    @$el.removeClass @errorClassName
    #Clear error message
    @$('[data-error]').empty()
    return
  commit: ->
    @editor.commit()
  getValue: ->
    @editor.getValue()
  setValue: (value) ->
    @editor.setValue value
    return
  focus: ->
    @editor.focus()
    return
  blur: ->
    @editor.blur()
    return
  remove: ->
    @editor.remove()
    Backbone.View::remove.call this
    return

},
  template: _.template('    <div>      <label for="<%= editorId %>">        <% if (titleHTML){ %><%= titleHTML %>        <% } else { %><%- title %><% } %>      </label>      <div>        <span data-editor></span>        <div data-error></div>        <div><%= help %></div>      </div>    </div>  ', null, Form.templateSettings)
  errorClassName: 'error')

#==================================================================================================
#NESTEDFIELD
#==================================================================================================
Form.NestedField = Form.Field.extend(template: _.template('    <div>      <label for="<%= editorId %>">        <% if (titleHTML){ %><%= titleHTML %>        <% } else { %><%- title %><% } %>      </label>      <div>        <span data-editor></span>        <div class="error-text" data-error></div>        <div class="error-help"><%= help %></div>      </div>    </div>  ', null, Form.templateSettings))

###*
# Base editor (interface). To be extended, not used directly
#
# @param {Object} options
# @param {String} [options.id]         Editor ID
# @param {Model} [options.model]       Use instead of value, and use commit()
# @param {String} [options.key]        The model attribute key. Required when using 'model'
# @param {Mixed} [options.value]       When not using a model. If neither provided, defaultValue will be used
# @param {Object} [options.schema]     Field schema; may be required by some editors
# @param {Object} [options.validators] Validators; falls back to those stored on schema
# @param {Object} [options.form]       The form
###

Form.Editor = Form.editors.Base = Backbone.View.extend(
  defaultValue: null
  hasFocus: false
  initialize: (options) ->
    `var options`
    options = options or {}
    #Set initial value
    if options.model
      if !options.key
        throw new Error('Missing option: \'key\'')
      @model = options.model
      @value = @model.get(options.key)
    else if options.value != undefined
      @value = options.value
    if @value == undefined
      @value = @defaultValue
    #Store important data
    _.extend this, _.pick(options, 'key', 'form')
    schema = @schema = options.schema or {}
    @validators = options.validators or schema.validators
    #Main attributes
    @$el.attr 'id', @id
    @$el.attr 'name', @getName()
    if schema.editorClass
      @$el.addClass schema.editorClass
    if schema.editorAttrs
      @$el.attr schema.editorAttrs
    return
  getName: ->
    key = @key or ''
    #Replace periods with underscores (e.g. for when using paths)
    key.replace /\./g, '_'
  getValue: ->
    @value
  setValue: (value) ->
    @value = value
    return
  focus: ->
    throw new Error('Not implemented')
    return
  blur: ->
    throw new Error('Not implemented')
    return
  commit: (options) ->
    error = @validate()
    if error
      return error
    @listenTo @model, 'invalid', (model, e) ->
      error = e
      return
    @model.set @key, @getValue(), options
    if error
      return error
    return
  validate: ->
    $el = @$el
    error = null
    value = @getValue()
    formValues = if @form then @form.getValue() else {}
    validators = @validators
    getValidator = @getValidator
    if validators
      #Run through validators until an error is found
      _.every validators, (validator) ->
        error = getValidator(validator)(value, formValues)
        if error then false else true
    error
  trigger: (event) ->
    if event == 'focus'
      @hasFocus = true
    else if event == 'blur'
      @hasFocus = false
    Backbone.View::trigger.apply this, arguments
  getValidator: (validator) ->
    validators = Form.validators
    #Convert regular expressions to validators
    if _.isRegExp(validator)
      return validators.regexp(regexp: validator)
    #Use a built-in validator if given a string
    if _.isString(validator)
      if !validators[validator]
        throw new Error('Validator "' + validator + '" not found')
      return validators[validator]()
    #Functions can be used directly
    if _.isFunction(validator)
      return validator
    #Use a customised built-in validator if given an object
    if _.isObject(validator) and validator.type
      config = validator
      return validators[config.type](config)
    #Unkown validator type
    throw new Error('Invalid validator: ' + validator)
    return
)

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

###*
# TextArea editor
###

Form.editors.TextArea = Form.editors.Text.extend(
  tagName: 'textarea'
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    return
)

###*
# Password editor
###

Form.editors.Password = Form.editors.Text.extend(initialize: (options) ->
  Form.editors.Text::initialize.call this, options
  @$el.attr 'type', 'password'
  return
)

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

###*
# Select editor
#
# Renders a <select> with given options
#
# Requires an 'options' value on the schema.
#  Can be an array of options, a function that calls back with the array of options, a string of HTML
#  or a Backbone collection. If a collection, the models must implement a toString() method
###

Form.editors.Select = Form.editors.Base.extend(
  tagName: 'select'
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
    'change': (event) ->
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
    if !@schema or !@schema.options
      throw new Error('Missing required \'schema.options\'')
    return
  render: ->
    @setOptions @schema.options
    this
  setOptions: (options) ->
    self = this
    #If a collection was passed, check if it needs fetching
    if options instanceof Backbone.Collection
      collection = options
      #Don't do the fetch if it's already populated
      if collection.length > 0
        @renderOptions options
      else
        collection.fetch success: (collection) ->
          self.renderOptions options
          return
    else if _.isFunction(options)
      options ((result) ->
        self.renderOptions result
        return
      ), self
    else
      @renderOptions options
    return
  renderOptions: (options) ->
    $select = @$el
    html = undefined
    html = @_getOptionsHtml(options)
    #Insert options
    $select.html html
    #Select correct option
    @setValue @value
    return
  _getOptionsHtml: (options) ->
    html = undefined
    #Accept string of HTML
    if _.isString(options)
      html = options
    else if _.isArray(options)
      html = @_arrayToHtml(options)
    else if options instanceof Backbone.Collection
      html = @_collectionToHtml(options)
    else if _.isFunction(options)
      newOptions = undefined
      options ((opts) ->
        newOptions = opts
        return
      ), this
      html = @_getOptionsHtml(newOptions)
      #Or any object
    else
      html = @_objectToHtml(options)
    html
  determineChange: (event) ->
    currentValue = @getValue()
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
  _collectionToHtml: (collection) ->
    #Convert collection to array first
    array = []
    collection.each (model) ->
      array.push
        val: model.id
        label: model.toString()
      return
    #Now convert to HTML
    html = @_arrayToHtml(array)
    html
  _objectToHtml: (obj) ->
    #Convert object to array first
    array = []
    for key of obj
      if obj.hasOwnProperty(key)
        array.push
          val: key
          label: obj[key]
    #Now convert to HTML
    html = @_arrayToHtml(array)
    html
  _arrayToHtml: (array) ->
    html = $()
    #Generate HTML
    _.each array, ((option) ->
      if _.isObject(option)
        if option.group
          optgroup = $('<optgroup>').attr('label', option.group).html(@_getOptionsHtml(option.options))
          html = html.add(optgroup)
        else
          val = if option.val or option.val == 0 then option.val else ''
          html = html.add($('<option>').val(val).text(option.label))
      else
        html = html.add($('<option>').text(option))
      return
    ), this
    html
)

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

###*
# Object editor
#
# Creates a child form. For editing Javascript objects
#
# @param {Object} options
# @param {Form} options.form                 The form this editor belongs to; used to determine the constructor for the nested form
# @param {Object} options.schema             The schema for the object
# @param {Object} options.schema.subSchema   The schema for the nested form
###

Form.editors.Object = Form.editors.Base.extend(
  hasNestedForm: true
  initialize: (options) ->
    #Set default value for the instance so it's not a shared object
    @value = {}
    #Init
    Form.editors.Base::initialize.call this, options
    #Check required options
    if !@form
      throw new Error('Missing required option "form"')
    if !@schema.subSchema
      throw new Error('Missing required \'schema.subSchema\' option for Object editor')
    return
  render: ->
    #Get the constructor for creating the nested form; i.e. the same constructor as used by the parent form
    NestedForm = @form.constructor
    #Create the nested form
    @nestedForm = new NestedForm(
      schema: @schema.subSchema
      data: @value
      idPrefix: @id + '_'
      Field: NestedForm.NestedField)
    @_observeFormEvents()
    @$el.html @nestedForm.render().el
    if @hasFocus
      @trigger 'blur', this
    this
  getValue: ->
    if @nestedForm
      return @nestedForm.getValue()
    @value
  setValue: (value) ->
    @value = value
    @render()
    return
  focus: ->
    if @hasFocus
      return
    @nestedForm.focus()
    return
  blur: ->
    if !@hasFocus
      return
    @nestedForm.blur()
    return
  remove: ->
    @nestedForm.remove()
    Backbone.View::remove.call this
    return
  validate: ->
    errors = _.extend({}, Form.editors.Base::validate.call(this), @nestedForm.validate())
    if _.isEmpty(errors) then false else errors
  _observeFormEvents: ->
    if !@nestedForm
      return
    @nestedForm.on 'all', (->
      # args = ["key:change", form, fieldEditor]
      args = _.toArray(arguments)
      args[1] = this
      # args = ["key:change", this=objectEditor, fieldEditor]
      @trigger.apply this, args
      return
    ), this
    return
)

###*
# NestedModel editor
#
# Creates a child form. For editing nested Backbone models
#
# Special options:
#   schema.model:   Embedded model constructor
###

Form.editors.NestedModel = Form.editors.Object.extend(
  initialize: (options) ->
    Form.editors.Base::initialize.call this, options
    if !@form
      throw new Error('Missing required option "form"')
    if !options.schema.model
      throw new Error('Missing required "schema.model" option for NestedModel editor')
    return
  render: ->
    #Get the constructor for creating the nested form; i.e. the same constructor as used by the parent form
    NestedForm = @form.constructor
    data = @value or {}
    key = @key
    nestedModel = @schema.model
    #Wrap the data in a model if it isn't already a model instance
    modelInstance = if data.constructor == nestedModel then data else new nestedModel(data)
    @nestedForm = new NestedForm(
      model: modelInstance
      idPrefix: @id + '_'
      fieldTemplate: 'nestedField')
    @_observeFormEvents()
    #Render form
    @$el.html @nestedForm.render().el
    if @hasFocus
      @trigger 'blur', this
    this
  commit: ->
    error = @nestedForm.commit()
    if error
      @$el.addClass 'error'
      return error
    Form.editors.Object::commit.call this
)

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

    pad = (n) ->
      if n < 10 then '0' + n else n

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

((Form) ->

  ###*
  # List editor
  # 
  # An array editor. Creates a list of other editor items.
  #
  # Special options:
  # @param {String} [options.schema.itemType]          The editor type for each item in the list. Default: 'Text'
  # @param {String} [options.schema.confirmDelete]     Text to display in a delete confirmation dialog. If falsey, will not ask for confirmation.
  ###

  Form.editors.List = Form.editors.Base.extend({
    events: 'click [data-action="add"]': (event) ->
      event.preventDefault()
      @addItem null, true
      return
    initialize: (options) ->
      options = options or {}
      editors = Form.editors
      editors.Base::initialize.call this, options
      schema = @schema
      if !schema
        throw new Error('Missing required option \'schema\'')
      @template = options.template or @constructor.template
      #Determine the editor to use
      @Editor = do ->
        type = schema.itemType
        #Default to Text
        if !type
          return editors.Text
        #Use List-specific version if available
        if editors.List[type]
          return editors.List[type]
        #Or whichever was passed
        editors[type]
      @items = []
      return
    render: ->
      self = this
      value = @value or []
      $ = Backbone.$
      #Create main element
      $el = $($.trim(@template()))
      #Store a reference to the list (item container)
      @$list = if $el.is('[data-items]') then $el else $el.find('[data-items]')
      #Add existing items
      if value.length
        _.each value, (itemValue) ->
          self.addItem itemValue
          return
      else
        if !@Editor.isAsync
          @addItem()
      @setElement $el
      @$el.attr 'id', @id
      @$el.attr 'name', @key
      if @hasFocus
        @trigger 'blur', this
      this
    addItem: (value, userInitiated) ->
      self = this
      editors = Form.editors
      #Create the item
      item = new (editors.List.Item)(
        list: this
        form: @form
        schema: @schema
        value: value
        Editor: @Editor
        key: @key).render()

      _addItem = ->
        self.items.push item
        self.$list.append item.el
        item.editor.on 'all', ((event) ->
          if event == 'change'
            return
          # args = ["key:change", itemEditor, fieldEditor]
          args = _.toArray(arguments)
          args[0] = 'item:' + event
          args.splice 1, 0, self
          # args = ["item:key:change", this=listEditor, itemEditor, fieldEditor]
          editors.List::trigger.apply this, args
          return
        ), self
        item.editor.on 'change', (->
          if !item.addEventTriggered
            item.addEventTriggered = true
            @trigger 'add', this, item.editor
          @trigger 'item:change', this, item.editor
          @trigger 'change', this
          return
        ), self
        item.editor.on 'focus', (->
          if @hasFocus
            return
          @trigger 'focus', this
          return
        ), self
        item.editor.on 'blur', (->
          `var self`
          if !@hasFocus
            return
          self = this
          setTimeout (->
            if _.find(self.items, ((item) ->
                item.editor.hasFocus
              ))
              return
            self.trigger 'blur', self
            return
          ), 0
          return
        ), self
        if userInitiated or value
          item.addEventTriggered = true
        if userInitiated
          self.trigger 'add', self, item.editor
          self.trigger 'change', self
        return

      #Check if we need to wait for the item to complete before adding to the list
      if @Editor.isAsync
        item.editor.on 'readyToAdd', _addItem, this
      else
        _addItem()
        item.editor.focus()
      item
    removeItem: (item) ->
      #Confirm delete
      confirmMsg = @schema.confirmDelete
      if confirmMsg and !confirm(confirmMsg)
        return
      index = _.indexOf(@items, item)
      @items[index].remove()
      @items.splice index, 1
      if item.addEventTriggered
        @trigger 'remove', this, item.editor
        @trigger 'change', this
      if !@items.length and !@Editor.isAsync
        @addItem()
      return
    getValue: ->
      values = _.map(@items, (item) ->
        item.getValue()
      )
      #Filter empty items
      _.without values, undefined, ''
    setValue: (value) ->
      @value = value
      @render()
      return
    focus: ->
      if @hasFocus
        return
      if @items[0]
        @items[0].editor.focus()
      return
    blur: ->
      if !@hasFocus
        return
      focusedItem = _.find(@items, (item) ->
        item.editor.hasFocus
      )
      if focusedItem
        focusedItem.editor.blur()
      return
    remove: ->
      _.invoke @items, 'remove'
      Form.editors.Base::remove.call this
      return
    validate: ->
      if !@validators
        return null
      #Collect errors
      errors = _.map(@items, (item) ->
        item.validate()
      )
      #Check if any item has errors
      hasErrors = if _.compact(errors).length then true else false
      if !hasErrors
        return null
      #If so create a shared error
      fieldError = 
        type: 'list'
        message: 'Some of the items in the list failed validation'
        errors: errors
      fieldError

  }, template: _.template('      <div>        <div data-items></div>        <button type="button" data-action="add">Add</button>      </div>    ', null, Form.templateSettings))

  ###*
  # A single item in the list
  #
  # @param {editors.List} options.list The List editor instance this item belongs to
  # @param {Function} options.Editor   Editor constructor function
  # @param {String} options.key        Model key
  # @param {Mixed} options.value       Value
  # @param {Object} options.schema     Field schema
  ###

  Form.editors.List.Item = Form.editors.Base.extend({
    events:
      'click [data-action="remove"]': (event) ->
        event.preventDefault()
        @list.removeItem this
        return
      'keydown input[type=text]': (event) ->
        if event.keyCode != 13
          return
        event.preventDefault()
        @list.addItem()
        @list.$list.find('> li:last input').focus()
        return
    initialize: (options) ->
      @list = options.list
      @schema = options.schema or @list.schema
      @value = options.value
      @Editor = options.Editor or Form.editors.Text
      @key = options.key
      @template = options.template or @schema.itemTemplate or @constructor.template
      @errorClassName = options.errorClassName or @constructor.errorClassName
      @form = options.form
      return
    render: ->
      $ = Backbone.$
      #Create editor
      @editor = new (@Editor)(
        key: @key
        schema: @schema
        value: @value
        list: @list
        item: this
        form: @form).render()
      #Create main element
      $el = $($.trim(@template()))
      $el.find('[data-editor]').append @editor.el
      #Replace the entire element so there isn't a wrapper tag
      @setElement $el
      this
    getValue: ->
      @editor.getValue()
    setValue: (value) ->
      @editor.setValue value
      return
    focus: ->
      @editor.focus()
      return
    blur: ->
      @editor.blur()
      return
    remove: ->
      @editor.remove()
      Backbone.View::remove.call this
      return
    validate: ->
      value = @getValue()
      formValues = if @list.form then @list.form.getValue() else {}
      validators = @schema.validators
      getValidator = @getValidator
      if !validators
        return null
      #Run through validators until an error is found
      error = null
      _.every validators, (validator) ->
        error = getValidator(validator)(value, formValues)
        if error then false else true
      #Show/hide error
      if error
        @setError error
      else
        @clearError()
      #Return error to be aggregated by list
      if error then error else null
    setError: (err) ->
      @$el.addClass @errorClassName
      @$el.attr 'title', err.message
      return
    clearError: ->
      @$el.removeClass @errorClassName
      @$el.attr 'title', null
      return

  },
    template: _.template('      <div>        <span data-editor></span>        <button type="button" data-action="remove">&times;</button>      </div>    ', null, Form.templateSettings)
    errorClassName: 'error')

  ###*
  # Base modal object editor for use with the List editor; used by Object 
  # and NestedModal list types
  ###

  Form.editors.List.Modal = Form.editors.Base.extend({
    events: 'click': 'openEditor'
    initialize: (options) ->
      options = options or {}
      Form.editors.Base::initialize.call this, options
      #Dependencies
      if !Form.editors.List.Modal.ModalAdapter
        throw new Error('A ModalAdapter is required')
      @form = options.form
      if !options.form
        throw new Error('Missing required option: "form"')
      #Template
      @template = options.template or @constructor.template
      return
    render: ->
      self = this
      #New items in the list are only rendered when the editor has been OK'd
      if _.isEmpty(@value)
        @openEditor()
      else
        @renderSummary()
        setTimeout (->
          self.trigger 'readyToAdd'
          return
        ), 0
      if @hasFocus
        @trigger 'blur', this
      this
    renderSummary: ->
      @$el.html $.trim(@template(summary: @getStringValue()))
      return
    itemToString: (value) ->

      createTitle = (key) ->
        context = key: key
        Form.Field::createTitle.call context

      value = value or {}
      #Pretty print the object keys and values
      parts = []
      _.each @nestedSchema, (schema, key) ->
        desc = if schema.title then schema.title else createTitle(key)
        val = value[key]
        if _.isUndefined(val) or _.isNull(val)
          val = ''
        parts.push desc + ': ' + val
        return
      parts.join '<br />'
    getStringValue: ->
      schema = @schema
      value = @getValue()
      if _.isEmpty(value)
        return '[Empty]'
      #If there's a specified toString use that
      if schema.itemToString
        return schema.itemToString(value)
      #Otherwise use the generic method or custom overridden method
      @itemToString value
    openEditor: ->
      self = this
      ModalForm = @form.constructor
      form = @modalForm = new ModalForm(
        schema: @nestedSchema
        data: @value)
      modal = @modal = new (Form.editors.List.Modal.ModalAdapter)(
        content: form
        animate: true)
      modal.open()
      @trigger 'open', this
      @trigger 'focus', this
      modal.on 'cancel', @onModalClosed, this
      modal.on 'ok', _.bind(@onModalSubmitted, this)
      return
    onModalSubmitted: ->
      modal = @modal
      form = @modalForm
      isNew = !@value
      #Stop if there are validation errors
      error = form.validate()
      if error
        return modal.preventClose()
      #Store form value
      @value = form.getValue()
      #Render item
      @renderSummary()
      if isNew
        @trigger 'readyToAdd'
      @trigger 'change', this
      @onModalClosed()
      return
    onModalClosed: ->
      @modal = null
      @modalForm = null
      @trigger 'close', this
      @trigger 'blur', this
      return
    getValue: ->
      @value
    setValue: (value) ->
      @value = value
      return
    focus: ->
      if @hasFocus
        return
      @openEditor()
      return
    blur: ->
      if !@hasFocus
        return
      if @modal
        @modal.trigger 'cancel'
      return

  },
    template: _.template('      <div><%= summary %></div>    ', null, Form.templateSettings)
    ModalAdapter: Backbone.BootstrapModal
    isAsync: true)
  Form.editors.List.Object = Form.editors.List.Modal.extend(initialize: ->
    Form.editors.List.Modal::initialize.apply this, arguments
    schema = @schema
    if !schema.subSchema
      throw new Error('Missing required option "schema.subSchema"')
    @nestedSchema = schema.subSchema
    return
  )
  Form.editors.List.NestedModel = Form.editors.List.Modal.extend(
    initialize: ->
      Form.editors.List.Modal::initialize.apply this, arguments
      schema = @schema
      if !schema.model
        throw new Error('Missing required option "schema.model"')
      nestedSchema = schema.model::schema
      @nestedSchema = if _.isFunction(nestedSchema) then nestedSchema() else nestedSchema
      return
    getStringValue: ->
      schema = @schema
      value = @getValue()
      if _.isEmpty(value)
        return null
      #If there's a specified toString use that
      if schema.itemToString
        return schema.itemToString(value)
      #Otherwise use the model
      new (schema.model)(value).toString()
  )
  return
) Backbone.Form
