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
  template: _.template '''
    <div>
      <label for="<%= editorId %>">
        <% if (titleHTML){ %>
          <%= titleHTML %>
        <% } else { %>
          <%- title %>
        <% } %>
      </label>

      <div>
        <div data-help><%= help %></div>
        <span data-editor></span>
        <div data-error></div>
      </div>
    </div>
  ''', null, Form.templateSettings
  errorClassName: 'error')
