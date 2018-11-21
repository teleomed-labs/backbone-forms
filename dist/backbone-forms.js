(function() {
  var Form;

  Form = Backbone.View.extend({
    events: {
      'submit': function(event) {
        this.trigger('submit', event);
      }
    },
    initialize: function(options) {
      var constructor, fields, fieldsetSchema, fieldsets, schema, selectedFields, self;
      self = this;
      options = this.options = _.extend({
        submitButton: false
      }, options);
      schema = this.schema = (function() {
        var model;
        if (options.schema) {
          return _.result(options, 'schema');
        }
        model = options.model;
        if (model && model.schema) {
          return _.result(model, 'schema');
        }
        if (self.schema) {
          return _.result(self, 'schema');
        }
        return {};
      })();
      _.extend(this, _.pick(options, 'model', 'data', 'idPrefix', 'templateData'));
      constructor = this.constructor;
      this.template = options.template || this.template || constructor.template;
      this.Fieldset = options.Fieldset || this.Fieldset || constructor.Fieldset;
      this.Field = options.Field || this.Field || constructor.Field;
      this.NestedField = options.NestedField || this.NestedField || constructor.NestedField;
      selectedFields = this.selectedFields = options.fields || this.fields || constructor.fields || _.keys(schema);
      fields = this.fields = {};
      _.each(selectedFields, (function(key) {
        var fieldSchema;
        fieldSchema = schema[key];
        fields[key] = this.createField(key, fieldSchema);
      }), this);
      fieldsetSchema = options.fieldsets || _.result(this, 'fieldsets') || _.result(this.model, 'fieldsets') || [selectedFields];
      fieldsets = this.fieldsets = [];
      _.each(fieldsetSchema, (function(itemSchema) {
        this.fieldsets.push(this.createFieldset(itemSchema));
      }), this);
    },
    createFieldset: function(schema) {
      var options;
      options = {
        schema: schema,
        fields: this.fields,
        legend: schema.legend || null
      };
      return new this.Fieldset(options);
    },
    createField: function(key, schema) {
      var field, options;
      options = {
        form: this,
        key: key,
        schema: schema,
        idPrefix: this.idPrefix
      };
      if (this.model) {
        options.model = this.model;
      } else if (this.data) {
        options.value = this.data[key];
      } else {
        options.value = null;
      }
      field = new this.Field(options);
      this.listenTo(field.editor, 'all', this.handleEditorEvent);
      return field;
    },
    handleEditorEvent: function(event, editor) {
      var formEvent, self;
      formEvent = editor.key + ':' + event;
      this.trigger.call(this, formEvent, this, editor, Array.prototype.slice.call(arguments, 2));
      switch (event) {
        case 'change':
          this.trigger('change', this);
          break;
        case 'focus':
          if (!this.hasFocus) {
            this.trigger('focus', this);
          }
          break;
        case 'blur':
          if (this.hasFocus) {
            self = this;
            setTimeout((function() {
              var focusedField;
              focusedField = _.find(self.fields, function(field) {
                return field.editor.hasFocus;
              });
              if (!focusedField) {
                self.trigger('blur', self);
              }
            }), 0);
          }
      }
    },
    getTemplate: function() {
      if (_.isString(this.template)) {
        return this.template = _.template(this.template);
      } else {
        return this.template;
      }
    },
    templateData: function() {
      var options;
      options = this.options;
      return {
        submitButton: options.submitButton
      };
    },
    render: function() {
      var $, $form, fields, self, tmpl;
      self = this;
      fields = this.fields;
      $ = Backbone.$;
      tmpl = this.getTemplate();
      $form = $($.trim(tmpl(_.result(this, 'templateData'))));
      $form.find('[data-editors]').add($form).each(function(i, el) {
        var $container, keys, selection;
        $container = $(el);
        selection = $container.attr('data-editors');
        if (_.isUndefined(selection)) {
          return;
        }
        keys = selection === '*' ? self.selectedFields || _.keys(fields) : selection.split(',');
        _.each(keys, function(key) {
          var field;
          field = fields[key];
          $container.append(field.editor.render().el);
        });
      });
      $form.find('[data-fields]').add($form).each(function(i, el) {
        var $container, keys, selection;
        $container = $(el);
        selection = $container.attr('data-fields');
        if (_.isUndefined(selection)) {
          return;
        }
        keys = selection === '*' ? self.selectedFields || _.keys(fields) : selection.split(',');
        _.each(keys, function(key) {
          var field;
          field = fields[key];
          $container.append(field.render().el);
        });
      });
      $form.find('[data-fieldsets]').add($form).each(function(i, el) {
        var $container, selection;
        $container = $(el);
        selection = $container.attr('data-fieldsets');
        if (_.isUndefined(selection)) {
          return;
        }
        _.each(self.fieldsets, function(fieldset) {
          $container.append(fieldset.render().el);
        });
      });
      this.setElement($form);
      $form.addClass(this.className);
      return this;
    },
    validate: function(options) {
      var errors, fields, isDictionary, model, modelErrors, self;
      self = this;
      fields = this.fields;
      model = this.model;
      errors = {};
      options = options || {};
      _.each(fields, function(field) {
        var error;
        error = field.validate();
        if (error) {
          errors[field.key] = error;
        }
      });
      if (!options.skipModelValidate && model && model.validate) {
        modelErrors = model.validate(this.getValue());
        if (modelErrors) {
          isDictionary = _.isObject(modelErrors) && !_.isArray(modelErrors);
          if (!isDictionary) {
            errors._others = errors._others || [];
            errors._others.push(modelErrors);
          }
          if (isDictionary) {
            _.each(modelErrors, function(val, key) {
              var tmpErr;
              if (fields[key] && !errors[key]) {
                fields[key].setError(val);
                errors[key] = val;
              } else {
                errors._others = errors._others || [];
                tmpErr = {};
                tmpErr[key] = val;
                errors._others.push(tmpErr);
              }
            });
          }
        }
      }
      if (_.isEmpty(errors)) {
        return null;
      } else {
        return errors;
      }
    },
    commit: function(options) {
      var errors, modelError, setOptions, validateOptions;
      options = options || {};
      validateOptions = {
        skipModelValidate: !options.validate
      };
      errors = this.validate(validateOptions);
      if (errors) {
        return errors;
      }
      modelError = void 0;
      setOptions = _.extend({
        error: function(model, e) {
          modelError = e;
        }
      }, options);
      this.model.set(this.getValue(), setOptions);
      if (modelError) {
        return modelError;
      }
    },
    getValue: function(key) {
      var values;
      if (key) {
        return this.fields[key].getValue();
      }
      values = {};
      _.each(this.fields, function(field) {
        values[field.key] = field.getValue();
      });
      return values;
    },
    setValue: function(prop, val) {
      var data, key;
      data = {};
      if (typeof prop === 'string') {
        data[prop] = val;
      } else {
        data = prop;
      }
      key = void 0;
      for (key in this.schema) {
        key = key;
        if (data[key] !== void 0) {
          this.fields[key].setValue(data[key]);
        }
      }
    },
    getEditor: function(key) {
      var field;
      field = this.fields[key];
      if (!field) {
        throw new Error('Field not found: ' + key);
      }
      return field.editor;
    },
    focus: function() {
      var field, fieldset;
      if (this.hasFocus) {
        return;
      }
      fieldset = this.fieldsets[0];
      field = fieldset.getFieldAt(0);
      if (!field) {
        return;
      }
      field.editor.focus();
    },
    blur: function() {
      var focusedField;
      if (!this.hasFocus) {
        return;
      }
      focusedField = _.find(this.fields, function(field) {
        return field.editor.hasFocus;
      });
      if (focusedField) {
        focusedField.editor.blur();
      }
    },
    trigger: function(event) {
      if (event === 'focus') {
        this.hasFocus = true;
      } else if (event === 'blur') {
        this.hasFocus = false;
      }
      return Backbone.View.prototype.trigger.apply(this, arguments);
    },
    remove: function() {
      _.each(this.fieldsets, function(fieldset) {
        fieldset.remove();
      });
      _.each(this.fields, function(field) {
        field.remove();
      });
      return Backbone.View.prototype.remove.apply(this, arguments);
    }
  }, {
    template: _.template('    <form>     <div data-fieldsets></div>      <% if (submitButton) { %>        <button type="submit"><%= submitButton %></button>      <% } %>    </form>  ', null, this.templateSettings),
    templateSettings: {
      evaluate: /<%([\s\S]+?)%>/g,
      interpolate: /<%=([\s\S]+?)%>/g,
      escape: /<%-([\s\S]+?)%>/g
    },
    editors: {}
  });

  Backbone.Form = Form;

  Form.validators = (function() {
    var validators;
    validators = {};
    validators.errMessages = {
      required: 'Required',
      regexp: 'Invalid',
      number: 'Must be a number',
      email: 'Invalid email address',
      url: 'Invalid URL',
      match: _.template('Must match field "<%= field %>"', null, Form.templateSettings)
    };
    validators.required = function(options) {
      options = _.extend({
        type: 'required',
        message: this.errMessages.required
      }, options);
      return function(value) {
        var err;
        options.value = value;
        err = {
          type: options.type,
          message: _.isFunction(options.message) ? options.message(options) : options.message
        };
        if (value === null || value === void 0 || value === false || value === '') {
          return err;
        }
      };
    };
    validators.regexp = function(options) {
      if (!options.regexp) {
        throw new Error('Missing required "regexp" option for "regexp" validator');
      }
      options = _.extend({
        type: 'regexp',
        match: true,
        message: this.errMessages.regexp
      }, options);
      return function(value) {
        var err;
        options.value = value;
        err = {
          type: options.type,
          message: _.isFunction(options.message) ? options.message(options) : options.message
        };
        if (value === null || value === void 0 || value === '') {
          return;
        }
        if ('string' === typeof options.regexp) {
          options.regexp = new RegExp(options.regexp, options.flags);
        }
        if ((options.match ? !options.regexp.test(value) : options.regexp.test(value))) {
          return err;
        }
      };
    };
    validators.number = function(options) {
      options = _.extend({
        type: 'number',
        message: this.errMessages.number,
        regexp: /^[0-9]*\.?[0-9]*?$/
      }, options);
      return validators.regexp(options);
    };
    validators.email = function(options) {
      options = _.extend({
        type: 'email',
        message: this.errMessages.email,
        regexp: /^[\w\-]{1,}([\w\-\+.]{1,1}[\w\-]{1,}){0,}[@][\w\-]{1,}([.]([\w\-]{1,})){1,3}$/
      }, options);
      return validators.regexp(options);
    };
    validators.url = function(options) {
      options = _.extend({
        type: 'url',
        message: this.errMessages.url,
        regexp: /^(http|https):\/\/(([A-Z0-9][A-Z0-9_\-]*)(\.[A-Z0-9][A-Z0-9_\-]*)+)(:(\d+))?\/?/i
      }, options);
      return validators.regexp(options);
    };
    validators.match = function(options) {
      if (!options.field) {
        throw new Error('Missing required "field" options for "match" validator');
      }
      options = _.extend({
        type: 'match',
        message: this.errMessages.match
      }, options);
      return function(value, attrs) {
        var err;
        options.value = value;
        err = {
          type: options.type,
          message: _.isFunction(options.message) ? options.message(options) : options.message
        };
        if (value === null || value === void 0 || value === '') {
          return;
        }
        if (value !== attrs[options.field]) {
          return err;
        }
      };
    };
    return validators;
  })();

  Form.Fieldset = Backbone.View.extend({
    initialize: function(options) {
      var schema;
      options = options || {};
      schema = this.schema = this.createSchema(options.schema);
      this.fields = _.pick(options.fields, schema.fields);
      this.template = options.template || schema.template || this.template || this.constructor.template;
    },
    createSchema: function(schema) {
      if (_.isArray(schema)) {
        schema = {
          fields: schema
        };
      }
      schema.legend = schema.legend || null;
      return schema;
    },
    getFieldAt: function(index) {
      var key;
      key = this.schema.fields[index];
      return this.fields[key];
    },
    templateData: function() {
      return this.schema;
    },
    render: function() {
      var $, $fieldset, fields, schema;
      schema = this.schema;
      fields = this.fields;
      $ = Backbone.$;
      $fieldset = $($.trim(this.template(_.result(this, 'templateData'))));
      $fieldset.find('[data-fields]').add($fieldset).each(function(i, el) {
        var $container, selection;
        $container = $(el);
        selection = $container.attr('data-fields');
        if (_.isUndefined(selection)) {
          return;
        }
        _.each(fields, function(field) {
          $container.append(field.render().el);
        });
      });
      this.setElement($fieldset);
      return this;
    },
    remove: function() {
      _.each(this.fields, function(field) {
        field.remove();
      });
      Backbone.View.prototype.remove.call(this);
    }
  }, {
    template: _.template('    <fieldset data-fields>      <% if (legend) { %>        <legend><%= legend %></legend>      <% } %>    </fieldset>  ', null, Form.templateSettings)
  });

  Form.Field = Backbone.View.extend({
    initialize: function(options) {
      var schema;
      options = options || {};
      _.extend(this, _.pick(options, 'form', 'key', 'model', 'value', 'idPrefix'));
      schema = this.schema = this.createSchema(options.schema);
      this.template = options.template || schema.template || this.template || this.constructor.template;
      this.errorClassName = options.errorClassName || this.errorClassName || this.constructor.errorClassName;
      this.editor = this.createEditor();
    },
    createSchema: function(schema) {
      if (_.isString(schema)) {
        schema = {
          type: schema
        };
      }
      schema = _.extend({
        type: 'Text',
        title: this.createTitle()
      }, schema);
      schema.type = _.isString(schema.type) ? Form.editors[schema.type] : schema.type;
      return schema;
    },
    createEditor: function() {
      var constructorFn, options;
      options = _.extend(_.pick(this, 'schema', 'form', 'key', 'model', 'value'), {
        id: this.createEditorId()
      });
      constructorFn = this.schema.type;
      return new constructorFn(options);
    },
    createEditorId: function() {
      var id, prefix;
      prefix = this.idPrefix;
      id = this.key;
      id = id.replace(/\./g, '_');
      if (_.isString(prefix) || _.isNumber(prefix)) {
        return prefix + id;
      }
      if (_.isNull(prefix)) {
        return id;
      }
      if (this.model) {
        return this.model.cid + '_' + id;
      }
      return id;
    },
    createTitle: function() {
      var str;
      str = this.key;
      str = str.replace(/([A-Z])/g, ' $1');
      str = str.replace(/^./, function(str) {
        return str.toUpperCase();
      });
      return str;
    },
    templateData: function() {
      var schema;
      schema = this.schema;
      return {
        help: schema.help || '',
        title: schema.title,
        titleHTML: schema.titleHTML,
        fieldAttrs: schema.fieldAttrs,
        editorAttrs: schema.editorAttrs,
        key: this.key,
        editorId: this.editor.id
      };
    },
    render: function() {
      var $, $field, editor, schema;
      schema = this.schema;
      editor = this.editor;
      $ = Backbone.$;
      if (this.editor.noField === true) {
        return this.setElement(editor.render().el);
      }
      $field = $($.trim(this.template(_.result(this, 'templateData'))));
      if (schema.fieldClass) {
        $field.addClass(schema.fieldClass);
      }
      if (schema.fieldAttrs) {
        $field.attr(schema.fieldAttrs);
      }
      $field.find('[data-editor]').add($field).each(function(i, el) {
        var $container, selection;
        $container = $(el);
        selection = $container.attr('data-editor');
        if (_.isUndefined(selection)) {
          return;
        }
        $container.append(editor.render().el);
      });
      this.setElement($field);
      return this;
    },
    disable: function() {
      var $input;
      if (_.isFunction(this.editor.disable)) {
        this.editor.disable();
      } else {
        $input = this.editor.$el;
        $input = $input.is('input') ? $input : $input.find('input');
        $input.attr('disabled', true);
      }
    },
    enable: function() {
      var $input;
      if (_.isFunction(this.editor.enable)) {
        this.editor.enable();
      } else {
        $input = this.editor.$el;
        $input = $input.is('input') ? $input : $input.find('input');
        $input.attr('disabled', false);
      }
    },
    validate: function() {
      var error;
      error = this.editor.validate();
      if (error) {
        this.setError(error.message);
      } else {
        this.clearError();
      }
      return error;
    },
    setError: function(msg) {
      if (this.editor.hasNestedForm) {
        return;
      }
      this.$el.addClass(this.errorClassName);
      this.$('[data-error]').html(msg);
    },
    clearError: function() {
      this.$el.removeClass(this.errorClassName);
      this.$('[data-error]').empty();
    },
    commit: function() {
      return this.editor.commit();
    },
    getValue: function() {
      return this.editor.getValue();
    },
    setValue: function(value) {
      this.editor.setValue(value);
    },
    focus: function() {
      this.editor.focus();
    },
    blur: function() {
      this.editor.blur();
    },
    remove: function() {
      this.editor.remove();
      Backbone.View.prototype.remove.call(this);
    }
  }, {
    template: _.template('    <div>      <label for="<%= editorId %>">        <% if (titleHTML){ %><%= titleHTML %>        <% } else { %><%- title %><% } %>      </label>      <div>        <span data-editor></span>        <div data-error></div>        <div><%= help %></div>      </div>    </div>  ', null, Form.templateSettings),
    errorClassName: 'error'
  });

  Form.NestedField = Form.Field.extend({
    template: _.template('    <div>      <label for="<%= editorId %>">        <% if (titleHTML){ %><%= titleHTML %>        <% } else { %><%- title %><% } %>      </label>      <div>        <span data-editor></span>        <div class="error-text" data-error></div>        <div class="error-help"><%= help %></div>      </div>    </div>  ', null, Form.templateSettings)
  });


  /**
   * Base editor (interface). To be extended, not used directly
   *
   * @param {Object} options
   * @param {String} [options.id]         Editor ID
   * @param {Model} [options.model]       Use instead of value, and use commit()
   * @param {String} [options.key]        The model attribute key. Required when using 'model'
   * @param {Mixed} [options.value]       When not using a model. If neither provided, defaultValue will be used
   * @param {Object} [options.schema]     Field schema; may be required by some editors
   * @param {Object} [options.validators] Validators; falls back to those stored on schema
   * @param {Object} [options.form]       The form
   */

  Form.Editor = Form.editors.Base = Backbone.View.extend({
    defaultValue: null,
    hasFocus: false,
    initialize: function(options) {
      var options;
      var schema;
      options = options || {};
      if (options.model) {
        if (!options.key) {
          throw new Error('Missing option: \'key\'');
        }
        this.model = options.model;
        this.value = this.model.get(options.key);
      } else if (options.value !== void 0) {
        this.value = options.value;
      }
      if (this.value === void 0) {
        this.value = this.defaultValue;
      }
      _.extend(this, _.pick(options, 'key', 'form'));
      schema = this.schema = options.schema || {};
      this.validators = options.validators || schema.validators;
      this.$el.attr('id', this.id);
      this.$el.attr('name', this.getName());
      if (schema.editorClass) {
        this.$el.addClass(schema.editorClass);
      }
      if (schema.editorAttrs) {
        this.$el.attr(schema.editorAttrs);
      }
    },
    getName: function() {
      var key;
      key = this.key || '';
      return key.replace(/\./g, '_');
    },
    getValue: function() {
      return this.value;
    },
    setValue: function(value) {
      this.value = value;
    },
    focus: function() {
      throw new Error('Not implemented');
    },
    blur: function() {
      throw new Error('Not implemented');
    },
    commit: function(options) {
      var error;
      error = this.validate();
      if (error) {
        return error;
      }
      this.listenTo(this.model, 'invalid', function(model, e) {
        error = e;
      });
      this.model.set(this.key, this.getValue(), options);
      if (error) {
        return error;
      }
    },
    validate: function() {
      var $el, error, formValues, getValidator, validators, value;
      $el = this.$el;
      error = null;
      value = this.getValue();
      formValues = this.form ? this.form.getValue() : {};
      validators = this.validators;
      getValidator = this.getValidator;
      if (validators) {
        _.every(validators, function(validator) {
          error = getValidator(validator)(value, formValues);
          if (error) {
            return false;
          } else {
            return true;
          }
        });
      }
      return error;
    },
    trigger: function(event) {
      if (event === 'focus') {
        this.hasFocus = true;
      } else if (event === 'blur') {
        this.hasFocus = false;
      }
      return Backbone.View.prototype.trigger.apply(this, arguments);
    },
    getValidator: function(validator) {
      var config, validators;
      validators = Form.validators;
      if (_.isRegExp(validator)) {
        return validators.regexp({
          regexp: validator
        });
      }
      if (_.isString(validator)) {
        if (!validators[validator]) {
          throw new Error('Validator "' + validator + '" not found');
        }
        return validators[validator]();
      }
      if (_.isFunction(validator)) {
        return validator;
      }
      if (_.isObject(validator) && validator.type) {
        config = validator;
        return validators[config.type](config);
      }
      throw new Error('Invalid validator: ' + validator);
    }
  });


  /**
   * Text
   * 
   * Text input with focus, blur and change events
   */

  Form.editors.Text = Form.Editor.extend({
    tagName: 'input',
    defaultValue: '',
    previousValue: '',
    events: {
      'keyup': 'determineChange',
      'keypress': function(event) {
        var self;
        self = this;
        setTimeout((function() {
          self.determineChange();
        }), 0);
      },
      'select': function(event) {
        this.trigger('select', this);
      },
      'focus': function(event) {
        this.trigger('focus', this);
      },
      'blur': function(event) {
        this.trigger('blur', this);
      }
    },
    initialize: function(options) {
      var schema, type;
      Form.editors.Base.prototype.initialize.call(this, options);
      schema = this.schema;
      type = 'text';
      if (schema && schema.editorAttrs && schema.editorAttrs.type) {
        type = schema.editorAttrs.type;
      }
      if (schema && schema.dataType) {
        type = schema.dataType;
      }
      this.$el.attr('type', type);
    },
    render: function() {
      this.setValue(this.value);
      return this;
    },
    determineChange: function(event) {
      var changed, currentValue;
      currentValue = this.$el.val();
      changed = currentValue !== this.previousValue;
      if (changed) {
        this.previousValue = currentValue;
        this.trigger('change', this);
      }
    },
    getValue: function() {
      return this.$el.val();
    },
    setValue: function(value) {
      this.value = value;
      this.$el.val(value);
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$el.focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$el.blur();
    },
    select: function() {
      this.$el.select();
    }
  });


  /**
   * TextArea editor
   */

  Form.editors.TextArea = Form.editors.Text.extend({
    tagName: 'textarea',
    initialize: function(options) {
      Form.editors.Base.prototype.initialize.call(this, options);
    }
  });


  /**
   * Password editor
   */

  Form.editors.Password = Form.editors.Text.extend({
    initialize: function(options) {
      Form.editors.Text.prototype.initialize.call(this, options);
      this.$el.attr('type', 'password');
    }
  });


  /**
   * NUMBER
   * 
   * Normal text input that only allows a number. Letters etc. are not entered.
   */

  Form.editors.Number = Form.editors.Text.extend({
    defaultValue: 0,
    events: _.extend({}, Form.editors.Text.prototype.events, {
      'keypress': 'onKeyPress',
      'change': 'onKeyPress'
    }),
    initialize: function(options) {
      var schema;
      Form.editors.Text.prototype.initialize.call(this, options);
      schema = this.schema;
      this.$el.attr('type', 'number');
      if (!schema || !schema.editorAttrs || !schema.editorAttrs.step) {
        this.$el.attr('step', 'any');
      }
    },
    onKeyPress: function(event) {
      var delayedDetermineChange, newVal, numeric, self;
      self = this;
      delayedDetermineChange = function() {
        setTimeout((function() {
          self.determineChange();
        }), 0);
      };
      if (event.charCode === 0) {
        delayedDetermineChange();
        return;
      }
      newVal = this.$el.val();
      if (event.charCode !== void 0) {
        newVal = newVal + String.fromCharCode(event.charCode);
      }
      numeric = /^[0-9]*\.?[0-9]*?$/.test(newVal);
      if (numeric) {
        delayedDetermineChange();
      } else {
        event.preventDefault();
      }
    },
    getValue: function() {
      var value;
      value = this.$el.val();
      if (value === '') {
        return null;
      } else {
        return parseFloat(value, 10);
      }
    },
    setValue: function(value) {
      value = (function() {
        if (_.isNumber(value)) {
          return value;
        }
        if (_.isString(value) && value !== '') {
          return parseFloat(value, 10);
        }
        return null;
      })();
      if (_.isNaN(value)) {
        value = null;
      }
      this.value = value;
      Form.editors.Text.prototype.setValue.call(this, value);
    }
  });


  /**
   * Hidden editor
   */

  Form.editors.Hidden = Form.editors.Text.extend({
    defaultValue: '',
    noField: true,
    initialize: function(options) {
      Form.editors.Text.prototype.initialize.call(this, options);
      this.$el.attr('type', 'hidden');
    },
    focus: function() {},
    blur: function() {}
  });


  /**
   * Checkbox editor
   *
   * Creates a single checkbox, i.e. boolean value
   */

  Form.editors.Checkbox = Form.editors.Base.extend({
    defaultValue: false,
    tagName: 'input',
    events: {
      'click': function(event) {
        this.trigger('change', this);
      },
      'focus': function(event) {
        this.trigger('focus', this);
      },
      'blur': function(event) {
        this.trigger('blur', this);
      }
    },
    initialize: function(options) {
      Form.editors.Base.prototype.initialize.call(this, options);
      this.$el.attr('type', 'checkbox');
    },
    render: function() {
      this.setValue(this.value);
      return this;
    },
    getValue: function() {
      return this.$el.prop('checked');
    },
    setValue: function(value) {
      if (value) {
        this.$el.prop('checked', true);
      } else {
        this.$el.prop('checked', false);
      }
      this.value = !!value;
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$el.focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$el.blur();
    }
  });


  /**
   * Select editor
   *
   * Renders a <select> with given options
   *
   * Requires an 'options' value on the schema.
   *  Can be an array of options, a function that calls back with the array of options, a string of HTML
   *  or a Backbone collection. If a collection, the models must implement a toString() method
   */

  Form.editors.Select = Form.editors.Base.extend({
    tagName: 'select',
    previousValue: '',
    events: {
      'keyup': 'determineChange',
      'keypress': function(event) {
        var self;
        self = this;
        setTimeout((function() {
          self.determineChange();
        }), 0);
      },
      'change': function(event) {
        this.trigger('change', this);
      },
      'focus': function(event) {
        this.trigger('focus', this);
      },
      'blur': function(event) {
        this.trigger('blur', this);
      }
    },
    initialize: function(options) {
      Form.editors.Base.prototype.initialize.call(this, options);
      if (!this.schema || !this.schema.options) {
        throw new Error('Missing required \'schema.options\'');
      }
    },
    render: function() {
      this.setOptions(this.schema.options);
      return this;
    },
    setOptions: function(options) {
      var collection, self;
      self = this;
      if (options instanceof Backbone.Collection) {
        collection = options;
        if (collection.length > 0) {
          this.renderOptions(options);
        } else {
          collection.fetch({
            success: function(collection) {
              self.renderOptions(options);
            }
          });
        }
      } else if (_.isFunction(options)) {
        options((function(result) {
          self.renderOptions(result);
        }), self);
      } else {
        this.renderOptions(options);
      }
    },
    renderOptions: function(options) {
      var $select, html;
      $select = this.$el;
      html = void 0;
      html = this._getOptionsHtml(options);
      $select.html(html);
      this.setValue(this.value);
    },
    _getOptionsHtml: function(options) {
      var html, newOptions;
      html = void 0;
      if (_.isString(options)) {
        html = options;
      } else if (_.isArray(options)) {
        html = this._arrayToHtml(options);
      } else if (options instanceof Backbone.Collection) {
        html = this._collectionToHtml(options);
      } else if (_.isFunction(options)) {
        newOptions = void 0;
        options((function(opts) {
          newOptions = opts;
        }), this);
        html = this._getOptionsHtml(newOptions);
      } else {
        html = this._objectToHtml(options);
      }
      return html;
    },
    determineChange: function(event) {
      var changed, currentValue;
      currentValue = this.getValue();
      changed = currentValue !== this.previousValue;
      if (changed) {
        this.previousValue = currentValue;
        this.trigger('change', this);
      }
    },
    getValue: function() {
      return this.$el.val();
    },
    setValue: function(value) {
      if ((value == null) && !this.value) {
        value = this.$('option').first().val();
      }
      this.value = value;
      this.$el.val(value);
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$el.focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$el.blur();
    },
    _collectionToHtml: function(collection) {
      var array, html;
      array = [];
      collection.each(function(model) {
        array.push({
          val: model.id,
          label: model.toString()
        });
      });
      html = this._arrayToHtml(array);
      return html;
    },
    _objectToHtml: function(obj) {
      var array, html, key;
      array = [];
      for (key in obj) {
        if (obj.hasOwnProperty(key)) {
          array.push({
            val: key,
            label: obj[key]
          });
        }
      }
      html = this._arrayToHtml(array);
      return html;
    },
    _arrayToHtml: function(array) {
      var html;
      html = $();
      _.each(array, (function(option) {
        var optgroup, val;
        if (_.isObject(option)) {
          if (option.group) {
            optgroup = $('<optgroup>').attr('label', option.group).html(this._getOptionsHtml(option.options));
            html = html.add(optgroup);
          } else {
            val = option.val || option.val === 0 ? option.val : '';
            html = html.add($('<option>').val(val).text(option.label));
          }
        } else {
          html = html.add($('<option>').text(option));
        }
      }), this);
      return html;
    }
  });


  /**
   * Radio editor
   *
   * Renders a <ul> with given options represented as <li> objects containing radio buttons
   *
   * Requires an 'options' value on the schema.
   *  Can be an array of options, a function that calls back with the array of options, a string of HTML
   *  or a Backbone collection. If a collection, the models must implement a toString() method
   */

  Form.editors.Radio = Form.editors.Select.extend({
    tagName: 'ul',
    events: {
      'change input[type=radio]': function() {
        this.trigger('change', this);
      },
      'focus input[type=radio]': function() {
        if (this.hasFocus) {
          return;
        }
        this.trigger('focus', this);
      },
      'blur input[type=radio]': function() {
        var self;
        if (!this.hasFocus) {
          return;
        }
        self = this;
        setTimeout((function() {
          if (self.$('input[type=radio]:focus')[0]) {
            return;
          }
          self.trigger('blur', self);
        }), 0);
      }
    },
    getTemplate: function() {
      return this.schema.template || this.constructor.template;
    },
    getValue: function() {
      return this.$('input[type=radio]:checked').val();
    },
    setValue: function(value) {
      this.value = value;
      this.$('input[type=radio]').val([value]);
    },
    focus: function() {
      var checked;
      if (this.hasFocus) {
        return;
      }
      checked = this.$('input[type=radio]:checked');
      if (checked[0]) {
        checked.focus();
        return;
      }
      this.$('input[type=radio]').first().focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$('input[type=radio]:focus').blur();
    },
    _arrayToHtml: function(array) {
      var id, items, name, self, template;
      self = this;
      template = this.getTemplate();
      name = self.getName();
      id = self.id;
      items = _.map(array, function(option, index) {
        var item;
        item = {
          name: name,
          id: id + '-' + index
        };
        if (_.isObject(option)) {
          item.value = option.val || option.val === 0 ? option.val : '';
          item.label = option.label;
          item.labelHTML = option.labelHTML;
        } else {
          item.value = option;
          item.label = option;
        }
        return item;
      });
      return template({
        items: items
      });
    }
  }, {
    template: _.template('    <% _.each(items, function(item) { %>      <li>        <input type="radio" name="<%= item.name %>" value="<%- item.value %>" id="<%= item.id %>" />        <label for="<%= item.id %>"><% if (item.labelHTML){ %><%= item.labelHTML %><% }else{ %><%- item.label %><% } %></label>      </li>    <% }); %>  ', null, Form.templateSettings)
  });


  /**
   * Checkboxes editor
   *
   * Renders a <ul> with given options represented as <li> objects containing checkboxes
   *
   * Requires an 'options' value on the schema.
   *  Can be an array of options, a function that calls back with the array of options, a string of HTML
   *  or a Backbone collection. If a collection, the models must implement a toString() method
   */

  Form.editors.Checkboxes = Form.editors.Select.extend({
    tagName: 'ul',
    groupNumber: 0,
    events: {
      'click input[type=checkbox]': function() {
        this.trigger('change', this);
      },
      'focus input[type=checkbox]': function() {
        if (this.hasFocus) {
          return;
        }
        this.trigger('focus', this);
      },
      'blur input[type=checkbox]': function() {
        var self;
        if (!this.hasFocus) {
          return;
        }
        self = this;
        setTimeout((function() {
          if (self.$('input[type=checkbox]:focus')[0]) {
            return;
          }
          self.trigger('blur', self);
        }), 0);
      }
    },
    getValue: function() {
      var values;
      values = [];
      this.$('input[type=checkbox]:checked').each(function() {
        values.push($(this).val());
      });
      return values;
    },
    setValue: function(values) {
      if (!_.isArray(values)) {
        values = [values];
      }
      this.value = values;
      this.$('input[type=checkbox]').val(values);
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$('input[type=checkbox]').first().focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$('input[type=checkbox]:focus').blur();
    },
    _arrayToHtml: function(array) {
      var html, self;
      html = $();
      self = this;
      _.each(array, function(option, index) {
        var close, itemHtml, originalId, val;
        itemHtml = $('<li>');
        if (_.isObject(option)) {
          if (option.group) {
            originalId = self.id;
            self.id += '-' + self.groupNumber++;
            itemHtml = $('<fieldset class="group">').append($('<legend>').text(option.group));
            itemHtml = itemHtml.append(self._arrayToHtml(option.options));
            self.id = originalId;
            close = false;
          } else {
            val = option.val || option.val === 0 ? option.val : '';
            itemHtml.append($('<input type="checkbox" name="' + self.getName() + '" id="' + self.id + '-' + index + '" />').val(val));
            if (option.labelHTML) {
              itemHtml.append($('<label for="' + self.id + '-' + index + '">').html(option.labelHTML));
            } else {
              itemHtml.append($('<label for="' + self.id + '-' + index + '">').text(option.label));
            }
          }
        } else {
          itemHtml.append($('<input type="checkbox" name="' + self.getName() + '" id="' + self.id + '-' + index + '" />').val(option));
          itemHtml.append($('<label for="' + self.id + '-' + index + '">').text(option));
        }
        html = html.add(itemHtml);
      });
      return html;
    }
  });


  /**
   * Object editor
   *
   * Creates a child form. For editing Javascript objects
   *
   * @param {Object} options
   * @param {Form} options.form                 The form this editor belongs to; used to determine the constructor for the nested form
   * @param {Object} options.schema             The schema for the object
   * @param {Object} options.schema.subSchema   The schema for the nested form
   */

  Form.editors.Object = Form.editors.Base.extend({
    hasNestedForm: true,
    initialize: function(options) {
      this.value = {};
      Form.editors.Base.prototype.initialize.call(this, options);
      if (!this.form) {
        throw new Error('Missing required option "form"');
      }
      if (!this.schema.subSchema) {
        throw new Error('Missing required \'schema.subSchema\' option for Object editor');
      }
    },
    render: function() {
      var NestedForm;
      NestedForm = this.form.constructor;
      this.nestedForm = new NestedForm({
        schema: this.schema.subSchema,
        data: this.value,
        idPrefix: this.id + '_',
        Field: NestedForm.NestedField
      });
      this._observeFormEvents();
      this.$el.html(this.nestedForm.render().el);
      if (this.hasFocus) {
        this.trigger('blur', this);
      }
      return this;
    },
    getValue: function() {
      if (this.nestedForm) {
        return this.nestedForm.getValue();
      }
      return this.value;
    },
    setValue: function(value) {
      this.value = value;
      this.render();
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.nestedForm.focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.nestedForm.blur();
    },
    remove: function() {
      this.nestedForm.remove();
      Backbone.View.prototype.remove.call(this);
    },
    validate: function() {
      var errors;
      errors = _.extend({}, Form.editors.Base.prototype.validate.call(this), this.nestedForm.validate());
      if (_.isEmpty(errors)) {
        return false;
      } else {
        return errors;
      }
    },
    _observeFormEvents: function() {
      if (!this.nestedForm) {
        return;
      }
      this.nestedForm.on('all', (function() {
        var args;
        args = _.toArray(arguments);
        args[1] = this;
        this.trigger.apply(this, args);
      }), this);
    }
  });


  /**
   * NestedModel editor
   *
   * Creates a child form. For editing nested Backbone models
   *
   * Special options:
   *   schema.model:   Embedded model constructor
   */

  Form.editors.NestedModel = Form.editors.Object.extend({
    initialize: function(options) {
      Form.editors.Base.prototype.initialize.call(this, options);
      if (!this.form) {
        throw new Error('Missing required option "form"');
      }
      if (!options.schema.model) {
        throw new Error('Missing required "schema.model" option for NestedModel editor');
      }
    },
    render: function() {
      var NestedForm, data, key, modelInstance, nestedModel;
      NestedForm = this.form.constructor;
      data = this.value || {};
      key = this.key;
      nestedModel = this.schema.model;
      modelInstance = data.constructor === nestedModel ? data : new nestedModel(data);
      this.nestedForm = new NestedForm({
        model: modelInstance,
        idPrefix: this.id + '_',
        fieldTemplate: 'nestedField'
      });
      this._observeFormEvents();
      this.$el.html(this.nestedForm.render().el);
      if (this.hasFocus) {
        this.trigger('blur', this);
      }
      return this;
    },
    commit: function() {
      var error;
      error = this.nestedForm.commit();
      if (error) {
        this.$el.addClass('error');
        return error;
      }
      return Form.editors.Object.prototype.commit.call(this);
    }
  });


  /**
   * Date editor
   *
   * Schema options
   * @param {Number|String} [options.schema.yearStart]  First year in list. Default: 100 years ago
   * @param {Number|String} [options.schema.yearEnd]    Last year in list. Default: current year
   *
   * Config options (if not set, defaults to options stored on the main Date class)
   * @param {Boolean} [options.showMonthNames]  Use month names instead of numbers. Default: true
   * @param {String[]} [options.monthNames]     Month names. Default: Full English names
   */

  Form.editors.Date = Form.editors.Base.extend({
    events: {
      'change select': function() {
        this.updateHidden();
        this.trigger('change', this);
      },
      'focus select': function() {
        if (this.hasFocus) {
          return;
        }
        this.trigger('focus', this);
      },
      'blur select': function() {
        var self;
        if (!this.hasFocus) {
          return;
        }
        self = this;
        setTimeout((function() {
          if (self.$('select:focus')[0]) {
            return;
          }
          self.trigger('blur', self);
        }), 0);
      }
    },
    initialize: function(options) {
      var Self, date, today;
      options = options || {};
      Form.editors.Base.prototype.initialize.call(this, options);
      Self = Form.editors.Date;
      today = new Date;
      this.options = _.extend({
        monthNames: Self.monthNames,
        showMonthNames: Self.showMonthNames
      }, options);
      this.schema = _.extend({
        yearStart: today.getFullYear() - 100,
        yearEnd: today.getFullYear()
      }, options.schema || {});
      if (this.value && !_.isDate(this.value)) {
        this.value = new Date(this.value);
      }
      if (!this.value) {
        date = new Date;
        date.setSeconds(0);
        date.setMilliseconds(0);
        this.value = date;
      }
      this.template = options.template || this.constructor.template;
    },
    render: function() {
      var $, $el, datesOptions, monthsOptions, options, schema, yearRange, yearsOptions;
      options = this.options;
      schema = this.schema;
      $ = Backbone.$;
      datesOptions = _.map(_.range(1, 32), function(date) {
        return '<option value="' + date + '">' + date + '</option>';
      });
      monthsOptions = _.map(_.range(0, 12), function(month) {
        var value;
        value = options.showMonthNames ? options.monthNames[month] : month + 1;
        return '<option value="' + month + '">' + value + '</option>';
      });
      yearRange = schema.yearStart < schema.yearEnd ? _.range(schema.yearStart, schema.yearEnd + 1) : _.range(schema.yearStart, schema.yearEnd - 1, -1);
      yearsOptions = _.map(yearRange, function(year) {
        return '<option value="' + year + '">' + year + '</option>';
      });
      $el = $($.trim(this.template({
        dates: datesOptions.join(''),
        months: monthsOptions.join(''),
        years: yearsOptions.join('')
      })));
      this.$date = $el.find('[data-type="date"]');
      this.$month = $el.find('[data-type="month"]');
      this.$year = $el.find('[data-type="year"]');
      this.$hidden = $('<input type="hidden" name="' + this.key + '" />');
      $el.append(this.$hidden);
      this.setValue(this.value);
      this.setElement($el);
      this.$el.attr('id', this.id);
      this.$el.attr('name', this.getName());
      if (this.hasFocus) {
        this.trigger('blur', this);
      }
      return this;
    },
    getValue: function() {
      var date, month, year;
      year = this.$year.val();
      month = this.$month.val();
      date = this.$date.val();
      if (!year || !month || !date) {
        return null;
      }
      return new Date(year, month, date);
    },
    setValue: function(date) {
      this.value = date;
      this.$date.val(date.getDate());
      this.$month.val(date.getMonth());
      this.$year.val(date.getFullYear());
      this.updateHidden();
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$('select').first().focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$('select:focus').blur();
    },
    updateHidden: function() {
      var val;
      val = this.getValue();
      if (_.isDate(val)) {
        val = val.toISOString();
      }
      this.$hidden.val(val);
    }
  }, {
    template: _.template('    <div>      <select data-type="date"><%= dates %></select>      <select data-type="month"><%= months %></select>      <select data-type="year"><%= years %></select>    </div>  ', null, Form.templateSettings),
    showMonthNames: true,
    monthNames: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
  });


  /**
   * DateTime editor
   *
   * @param {Editor} [options.DateEditor]           Date editor view to use (not definition)
   * @param {Number} [options.schema.minsInterval]  Interval between minutes. Default: 15
   */

  Form.editors.DateTime = Form.editors.Base.extend({
    events: {
      'change select': function() {
        this.updateHidden();
        this.trigger('change', this);
      },
      'focus select': function() {
        if (this.hasFocus) {
          return;
        }
        this.trigger('focus', this);
      },
      'blur select': function() {
        var self;
        if (!this.hasFocus) {
          return;
        }
        self = this;
        setTimeout((function() {
          if (self.$('select:focus')[0]) {
            return;
          }
          self.trigger('blur', self);
        }), 0);
      }
    },
    initialize: function(options) {
      options = options || {};
      Form.editors.Base.prototype.initialize.call(this, options);
      this.options = _.extend({
        DateEditor: Form.editors.DateTime.DateEditor
      }, options);
      this.schema = _.extend({
        minsInterval: 15
      }, options.schema || {});
      this.dateEditor = new this.options.DateEditor(options);
      this.value = this.dateEditor.value;
      this.template = options.template || this.constructor.template;
    },
    render: function() {
      var $, $el, hoursOptions, minsOptions, pad, schema;
      pad = function(n) {
        if (n < 10) {
          return '0' + n;
        } else {
          return n;
        }
      };
      schema = this.schema;
      $ = Backbone.$;
      hoursOptions = _.map(_.range(0, 24), function(hour) {
        return '<option value="' + hour + '">' + pad(hour) + '</option>';
      });
      minsOptions = _.map(_.range(0, 60, schema.minsInterval), function(min) {
        return '<option value="' + min + '">' + pad(min) + '</option>';
      });
      $el = $($.trim(this.template({
        hours: hoursOptions.join(),
        mins: minsOptions.join()
      })));
      $el.find('[data-date]').append(this.dateEditor.render().el);
      this.$hour = $el.find('select[data-type="hour"]');
      this.$min = $el.find('select[data-type="min"]');
      this.$hidden = $el.find('input[type="hidden"]');
      this.setValue(this.value);
      this.setElement($el);
      this.$el.attr('id', this.id);
      this.$el.attr('name', this.getName());
      if (this.hasFocus) {
        this.trigger('blur', this);
      }
      return this;
    },
    getValue: function() {
      var date, hour, min;
      date = this.dateEditor.getValue();
      hour = this.$hour.val();
      min = this.$min.val();
      if (!date || !hour || !min) {
        return null;
      }
      date.setHours(hour);
      date.setMinutes(min);
      return date;
    },
    setValue: function(date) {
      if (!_.isDate(date)) {
        date = new Date(date);
      }
      this.value = date;
      this.dateEditor.setValue(date);
      this.$hour.val(date.getHours());
      this.$min.val(date.getMinutes());
      this.updateHidden();
    },
    focus: function() {
      if (this.hasFocus) {
        return;
      }
      this.$('select').first().focus();
    },
    blur: function() {
      if (!this.hasFocus) {
        return;
      }
      this.$('select:focus').blur();
    },
    updateHidden: function() {
      var val;
      val = this.getValue();
      if (_.isDate(val)) {
        val = val.toISOString();
      }
      this.$hidden.val(val);
    },
    remove: function() {
      this.dateEditor.remove();
      Form.editors.Base.prototype.remove.call(this);
    }
  }, {
    template: _.template('    <div class="bbf-datetime">      <div class="bbf-date-container" data-date></div>      <select data-type="hour"><%= hours %></select>      :      <select data-type="min"><%= mins %></select>    </div>  ', null, Form.templateSettings),
    DateEditor: Form.editors.Date
  });

  (function(Form) {

    /**
     * List editor
     * 
     * An array editor. Creates a list of other editor items.
     *
     * Special options:
     * @param {String} [options.schema.itemType]          The editor type for each item in the list. Default: 'Text'
     * @param {String} [options.schema.confirmDelete]     Text to display in a delete confirmation dialog. If falsey, will not ask for confirmation.
     */
    Form.editors.List = Form.editors.Base.extend({
      events: {
        'click [data-action="add"]': function(event) {
          event.preventDefault();
          this.addItem(null, true);
        }
      },
      initialize: function(options) {
        var editors, schema;
        options = options || {};
        editors = Form.editors;
        editors.Base.prototype.initialize.call(this, options);
        schema = this.schema;
        if (!schema) {
          throw new Error('Missing required option \'schema\'');
        }
        this.template = options.template || schema.listTemplate || this.constructor.template;
        this.Editor = (function() {
          var type;
          type = schema.itemType;
          if (!type) {
            return editors.Text;
          }
          if (editors.List[type]) {
            return editors.List[type];
          }
          if (_.isString(type)) {
            return editors[type];
          } else {
            return type;
          }
        })();
        this.ListItem = schema.itemClass || editors.List.Item;
        this.items = [];
      },
      render: function() {
        var $, $el, domReferencedElement, self, value;
        self = this;
        value = this.value || [];
        $ = Backbone.$;
        $el = $($.trim(this.template()));
        this.$list = $el.is('[data-items]') ? $el : $el.find('[data-items]');
        if (value.length) {
          _.each(value, function(itemValue) {
            self.addItem(itemValue);
          });
        } else {
          if (!this.Editor.isAsync) {
            this.addItem();
          }
        }
        domReferencedElement = this.el;
        this.setElement($el);
        if (domReferencedElement) {
          $(domReferencedElement).replaceWith(this.el);
        }
        this.$el.attr('id', this.id);
        this.$el.attr('name', this.key);
        if (this.hasFocus) {
          this.trigger('blur', this);
        }
        return this;
      },
      addItem: function(value, userInitiated) {
        var _addItem, editors, item, self;
        self = this;
        editors = Form.editors;
        item = new this.ListItem({
          list: this,
          form: this.form,
          schema: this.schema,
          value: value,
          Editor: this.Editor,
          key: this.key
        }).render();
        _addItem = function() {
          self.items.push(item);
          self.$list.append(item.el);
          item.editor.on('all', (function(event) {
            var args;
            if (event === 'change') {
              return;
            }
            args = _.toArray(arguments);
            args[0] = 'item:' + event;
            args.splice(1, 0, self);
            editors.List.prototype.trigger.apply(this, args);
          }), self);
          item.editor.on('change', (function() {
            if (!item.addEventTriggered) {
              item.addEventTriggered = true;
              this.trigger('add', this, item.editor);
            }
            this.trigger('item:change', this, item.editor);
            this.trigger('change', this);
          }), self);
          item.editor.on('focus', (function() {
            if (this.hasFocus) {
              return;
            }
            this.trigger('focus', this);
          }), self);
          item.editor.on('blur', (function() {
            var self;
            if (!this.hasFocus) {
              return;
            }
            self = this;
            setTimeout((function() {
              if (_.find(self.items, (function(item) {
                return item.editor.hasFocus;
              }))) {
                return;
              }
              self.trigger('blur', self);
            }), 0);
          }), self);
          if (userInitiated || value) {
            item.addEventTriggered = true;
          }
          if (userInitiated) {
            self.trigger('add', self, item.editor);
            self.trigger('change', self);
          }
        };
        if (this.Editor.isAsync) {
          item.editor.on('readyToAdd', _addItem, this);
        } else {
          _addItem();
          item.editor.focus();
        }
        return item;
      },
      removeItem: function(item) {
        var confirmMsg, index;
        confirmMsg = this.schema.confirmDelete;
        if (confirmMsg && !confirm(confirmMsg)) {
          return;
        }
        index = _.indexOf(this.items, item);
        this.items[index].remove();
        this.items.splice(index, 1);
        if (item.addEventTriggered) {
          this.trigger('remove', this, item.editor);
          this.trigger('change', this);
        }
        if (!this.items.length && !this.Editor.isAsync) {
          this.addItem();
        }
      },
      getValue: function() {
        var values;
        values = _.map(this.items, function(item) {
          return item.getValue();
        });
        return _.without(values, void 0, '');
      },
      setValue: function(value) {
        this.items = [];
        this.value = value;
        this.render();
      },
      focus: function() {
        if (this.hasFocus) {
          return;
        }
        if (this.items[0]) {
          this.items[0].editor.focus();
        }
      },
      blur: function() {
        var focusedItem;
        if (!this.hasFocus) {
          return;
        }
        focusedItem = _.find(this.items, function(item) {
          return item.editor.hasFocus;
        });
        if (focusedItem) {
          focusedItem.editor.blur();
        }
      },
      remove: function() {
        _.invoke(this.items, 'remove');
        Form.editors.Base.prototype.remove.call(this);
      },
      validate: function() {
        var errors, fieldError, hasErrors;
        if (!this.validators) {
          return null;
        }
        errors = _.map(this.items, function(item) {
          return item.validate();
        });
        hasErrors = _.compact(errors).length ? true : false;
        if (!hasErrors) {
          return null;
        }
        fieldError = {
          type: 'list',
          message: 'Some of the items in the list failed validation',
          errors: errors
        };
        return fieldError;
      }
    }, {
      template: _.template('      <div>        <div data-items></div>        <button type="button" data-action="add">Add</button>      </div>    ', null, Form.templateSettings)
    });

    /**
     * A single item in the list
     *
     * @param {editors.List} options.list The List editor instance this item belongs to
     * @param {Function} options.Editor   Editor constructor function
     * @param {String} options.key        Model key
     * @param {Mixed} options.value       Value
     * @param {Object} options.schema     Field schema
     */
    Form.editors.List.Item = Form.editors.Base.extend({
      events: {
        'click [data-action="remove"]': function(event) {
          event.preventDefault();
          this.list.removeItem(this);
        },
        'keydown input[type=text]': function(event) {
          if (event.keyCode !== 13) {
            return;
          }
          event.preventDefault();
          this.list.addItem();
          this.list.$list.find('> li:last input').focus();
        }
      },
      initialize: function(options) {
        this.list = options.list;
        this.schema = options.schema || this.list.schema;
        this.value = options.value;
        this.Editor = options.Editor || Form.editors.Text;
        this.key = options.key;
        this.template = options.template || this.schema.itemTemplate || this.constructor.template;
        this.errorClassName = options.errorClassName || this.constructor.errorClassName;
        this.form = options.form;
      },
      render: function() {
        var $, $el;
        $ = Backbone.$;
        this.editor = new this.Editor({
          key: this.key,
          schema: this.schema,
          value: this.value,
          list: this.list,
          item: this,
          form: this.form
        }).render();
        $el = $($.trim(this.template()));
        $el.find('[data-editor]').append(this.editor.el);
        this.setElement($el);
        return this;
      },
      getValue: function() {
        return this.editor.getValue();
      },
      setValue: function(value) {
        this.editor.setValue(value);
      },
      focus: function() {
        this.editor.focus();
      },
      blur: function() {
        this.editor.blur();
      },
      remove: function() {
        this.editor.remove();
        Backbone.View.prototype.remove.call(this);
      },
      validate: function() {
        var error, formValues, getValidator, validators, value;
        value = this.getValue();
        formValues = this.list.form ? this.list.form.getValue() : {};
        validators = this.schema.validators;
        getValidator = this.getValidator;
        if (!validators) {
          return null;
        }
        error = null;
        _.every(validators, function(validator) {
          error = getValidator(validator)(value, formValues);
          if (error) {
            return false;
          } else {
            return true;
          }
        });
        if (error) {
          this.setError(error);
        } else {
          this.clearError();
        }
        if (error) {
          return error;
        } else {
          return null;
        }
      },
      setError: function(err) {
        this.$el.addClass(this.errorClassName);
        this.$el.attr('title', err.message);
      },
      clearError: function() {
        this.$el.removeClass(this.errorClassName);
        this.$el.attr('title', null);
      }
    }, {
      template: _.template('      <div>        <span data-editor></span>        <button type="button" data-action="remove">&times;</button>      </div>    ', null, Form.templateSettings),
      errorClassName: 'error'
    });

    /**
     * Base modal object editor for use with the List editor; used by Object 
     * and NestedModal list types
     */
    Form.editors.List.Modal = Form.editors.Base.extend({
      events: {
        'click': 'openEditor'
      },
      initialize: function(options) {
        options = options || {};
        Form.editors.Base.prototype.initialize.call(this, options);
        if (!Form.editors.List.Modal.ModalAdapter) {
          throw new Error('A ModalAdapter is required');
        }
        this.form = options.form;
        if (!options.form) {
          throw new Error('Missing required option: "form"');
        }
        this.template = options.template || this.constructor.template;
      },
      render: function() {
        var self;
        self = this;
        if (_.isEmpty(this.value)) {
          this.openEditor();
        } else {
          this.renderSummary();
          setTimeout((function() {
            self.trigger('readyToAdd');
          }), 0);
        }
        if (this.hasFocus) {
          this.trigger('blur', this);
        }
        return this;
      },
      renderSummary: function() {
        this.$el.html($.trim(this.template({
          summary: this.getStringValue()
        })));
      },
      itemToString: function(value) {
        var createTitle, parts;
        createTitle = function(key) {
          var context;
          context = {
            key: key
          };
          return Form.Field.prototype.createTitle.call(context);
        };
        value = value || {};
        parts = [];
        _.each(this.nestedSchema, function(schema, key) {
          var desc, val;
          desc = schema.title ? schema.title : createTitle(key);
          val = value[key];
          if (_.isUndefined(val) || _.isNull(val)) {
            val = '';
          }
          parts.push(desc + ': ' + val);
        });
        return parts.join('<br />');
      },
      getStringValue: function() {
        var schema, value;
        schema = this.schema;
        value = this.getValue();
        if (_.isEmpty(value)) {
          return '[Empty]';
        }
        if (schema.itemToString) {
          return schema.itemToString(value);
        }
        return this.itemToString(value);
      },
      openEditor: function() {
        var ModalForm, form, modal, self;
        self = this;
        ModalForm = Backbone.Form;
        form = this.modalForm = new ModalForm({
          schema: this.nestedSchema,
          data: this.value
        });
        modal = this.modal = new Form.editors.List.Modal.ModalAdapter({
          content: form,
          animate: true
        });
        modal.open();
        this.trigger('open', this);
        this.trigger('focus', this);
        modal.on('cancel', this.onModalClosed, this);
        modal.on('ok', _.bind(this.onModalSubmitted, this));
      },
      onModalSubmitted: function() {
        var error, form, isNew, modal;
        modal = this.modal;
        form = this.modalForm;
        isNew = !this.value;
        error = form.validate();
        if (error) {
          return modal.preventClose();
        }
        this.value = form.getValue();
        this.renderSummary();
        if (isNew) {
          this.trigger('readyToAdd');
        }
        this.trigger('change', this);
        this.onModalClosed();
      },
      onModalClosed: function() {
        this.modal = null;
        this.modalForm = null;
        this.trigger('close', this);
        this.trigger('blur', this);
      },
      getValue: function() {
        return this.value;
      },
      setValue: function(value) {
        this.value = value;
      },
      focus: function() {
        if (this.hasFocus) {
          return;
        }
        this.openEditor();
      },
      blur: function() {
        if (!this.hasFocus) {
          return;
        }
        if (this.modal) {
          this.modal.trigger('cancel');
        }
      }
    }, {
      template: _.template('      <div><%= summary %></div>    ', null, Form.templateSettings),
      ModalAdapter: Backbone.BootstrapModal,
      isAsync: true
    });
    Form.editors.List.Object = Form.editors.List.Modal.extend({
      initialize: function() {
        var schema;
        Form.editors.List.Modal.prototype.initialize.apply(this, arguments);
        schema = this.schema;
        if (!schema.subSchema) {
          throw new Error('Missing required option "schema.subSchema"');
        }
        this.nestedSchema = schema.subSchema;
      }
    });
    Form.editors.List.NestedModel = Form.editors.List.Modal.extend({
      initialize: function() {
        var nestedSchema, schema;
        Form.editors.List.Modal.prototype.initialize.apply(this, arguments);
        schema = this.schema;
        if (!schema.model) {
          throw new Error('Missing required option "schema.model"');
        }
        nestedSchema = schema.model.prototype.schema;
        this.nestedSchema = _.isFunction(nestedSchema) ? nestedSchema() : nestedSchema;
      },
      getStringValue: function() {
        var schema, value;
        schema = this.schema;
        value = this.getValue();
        if (_.isEmpty(value)) {
          return null;
        }
        if (schema.itemToString) {
          return schema.itemToString(value);
        }
        return new schema.model(value).toString();
      }
    });
  })(Backbone.Form);

}).call(this);
