#==================================================================================================
# NESTEDFIELD
#==================================================================================================
Form.NestedField = Form.Field.extend
  template: _.template '''
      <div>
        <label for="<%= editorId %>">
          <% if (titleHTML) { %>
            <%= titleHTML %>
          <% } else { %>
            <%- title %>
          <% } %>
        </label>

        <div>
          <div class="error-help" data-help><%= help %></div>
          <span data-editor></span>
          <div class="error-text" data-error></div>
        </div>
      </div>
    ''', null, Form.templateSettings
