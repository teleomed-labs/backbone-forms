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
      @template = options.template or schema.listTemplate or @constructor.template
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
        if _.isString(type)
          editors[type]
        else
          type

      @ListItem = schema.itemClass or editors.List.Item
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
      #Save a copy of the pre-exising element, if exists
      domReferencedElement = @el
      @setElement $el
      #In case of there was a pre-existing element already placed in the DOM, then update it
      if domReferencedElement
        $(domReferencedElement).replaceWith @el
      @$el.attr 'id', @id
      @$el.attr 'name', @key
      if @hasFocus
        @trigger 'blur', this
      this
    addItem: (value, userInitiated) ->
      self = this
      editors = Form.editors
      #Create the item
      item = new (@ListItem)(
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
      @items = []
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
      ModalForm = Backbone.Form
      options = _.extend {}, @nestedFormAttributes,
        schema: @nestedSchema
        data: @value
      form = @modalForm = new ModalForm(options)
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
    @nestedFormAttributes = schema.formAttributes or {}
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
