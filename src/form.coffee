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
    selectedFields = @selectedFields = options.fields or @fields or constructor.fields or _.keys(schema)
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
  # Accept a function, or an Underscore-formatted string, as a form template.
  getTemplate: ->
    if _.isString(@template)
      @template = _.template @template
    else
      @template
  templateData: ->
    options = @options
    { submitButton: options.submitButton }
  render: ->
    self = this
    fields = @fields
    $ = Backbone.$
    #Render form
    tmpl = @getTemplate()
    $form = $($.trim(tmpl(_.result(this, 'templateData'))))
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
