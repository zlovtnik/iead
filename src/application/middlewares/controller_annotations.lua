-- src/application/middlewares/controller_annotations.lua
-- System for adding documentation annotations to controllers

local ControllerAnnotations = {}

-- Registry for controller annotations
ControllerAnnotations._annotations = {}

-- Add documentation annotation to a controller method
-- @param controller_name string Name of the controller
-- @param method_name string Name of the method
-- @param annotation table Documentation annotation
function ControllerAnnotations.annotate(controller_name, method_name, annotation)
  local key = controller_name .. "." .. method_name
  
  ControllerAnnotations._annotations[key] = {
    controller = controller_name,
    method = method_name,
    summary = annotation.summary,
    description = annotation.description,
    tags = annotation.tags or {},
    parameters = annotation.parameters or {},
    request_body = annotation.request_body,
    responses = annotation.responses or {},
    examples = annotation.examples or {},
    deprecated = annotation.deprecated or false,
    security = annotation.security or {},
    operation_id = annotation.operation_id or (controller_name:lower() .. "_" .. method_name:lower())
  }
end

-- Get annotation for a controller method
-- @param controller_name string Name of the controller
-- @param method_name string Name of the method
-- @return table|nil Annotation or nil if not found
function ControllerAnnotations.get_annotation(controller_name, method_name)
  local key = controller_name .. "." .. method_name
  return ControllerAnnotations._annotations[key]
end

-- Get all annotations
-- @return table All registered annotations
function ControllerAnnotations.get_all_annotations()
  return ControllerAnnotations._annotations
end

-- Create annotated controller wrapper
-- @param controller table The controller object
-- @param controller_name string Name of the controller
-- @param annotations table Map of method names to annotations
-- @return table Annotated controller
function ControllerAnnotations.create_annotated_controller(controller, controller_name, annotations)
  local annotated_controller = {}
  
  -- Copy all controller methods
  for method_name, method_func in pairs(controller) do
    if type(method_func) == "function" then
      annotated_controller[method_name] = method_func
      
      -- Register annotation if provided
      if annotations and annotations[method_name] then
        ControllerAnnotations.annotate(controller_name, method_name, annotations[method_name])
      end
    end
  end
  
  return annotated_controller
end

-- Helper to create standard CRUD annotations
-- @param resource_name string Name of the resource (e.g., "member", "event")
-- @param resource_schema table Validation schema for the resource
-- @return table Standard CRUD annotations
function ControllerAnnotations.create_crud_annotations(resource_name, resource_schema)
  local resource_title = resource_name:gsub("^%l", string.upper)
  
  return {
    index = {
      summary = "List " .. resource_name .. "s",
      description = "Retrieve a paginated list of " .. resource_name .. "s",
      tags = { resource_name },
      parameters = {
        {
          name = "page",
          ["in"] = "query",
          schema = { type = "integer", minimum = 1, default = 1 },
          description = "Page number for pagination"
        },
        {
          name = "per_page",
          ["in"] = "query", 
          schema = { type = "integer", minimum = 1, maximum = 100, default = 20 },
          description = "Number of items per page"
        }
      },
      responses = {
        ["200"] = {
          description = "Successful response",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = {
                    type = "array",
                    items = { ["$ref"] = "#/components/schemas/" .. resource_title }
                  },
                  pagination = {
                    type = "object",
                    properties = {
                      current_page = { type = "integer" },
                      per_page = { type = "integer" },
                      total_items = { type = "integer" },
                      total_pages = { type = "integer" },
                      has_next = { type = "boolean" },
                      has_previous = { type = "boolean" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    
    show = {
      summary = "Get " .. resource_name .. " by ID",
      description = "Retrieve a specific " .. resource_name .. " by its ID",
      tags = { resource_name },
      parameters = {
        {
          name = "id",
          ["in"] = "path",
          required = true,
          schema = { type = "integer" },
          description = "The " .. resource_name .. " ID"
        }
      },
      responses = {
        ["200"] = {
          description = "Successful response",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = { ["$ref"] = "#/components/schemas/" .. resource_title }
                }
              }
            }
          }
        },
        ["404"] = {
          description = resource_title .. " not found"
        }
      }
    },
    
    create = {
      summary = "Create new " .. resource_name,
      description = "Create a new " .. resource_name .. " record",
      tags = { resource_name },
      request_body = {
        required = true,
        content = {
          ["application/json"] = {
            schema = resource_schema and { ["$ref"] = "#/components/schemas/" .. resource_title .. "Create" } or { type = "object" }
          }
        }
      },
      responses = {
        ["201"] = {
          description = resource_title .. " created successfully",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = { ["$ref"] = "#/components/schemas/" .. resource_title }
                }
              }
            }
          }
        },
        ["400"] = {
          description = "Validation error"
        }
      }
    },
    
    update = {
      summary = "Update " .. resource_name,
      description = "Update an existing " .. resource_name .. " record",
      tags = { resource_name },
      parameters = {
        {
          name = "id",
          ["in"] = "path",
          required = true,
          schema = { type = "integer" },
          description = "The " .. resource_name .. " ID"
        }
      },
      request_body = {
        required = true,
        content = {
          ["application/json"] = {
            schema = resource_schema and { ["$ref"] = "#/components/schemas/" .. resource_title .. "Update" } or { type = "object" }
          }
        }
      },
      responses = {
        ["200"] = {
          description = resource_title .. " updated successfully",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = { ["$ref"] = "#/components/schemas/" .. resource_title }
                }
              }
            }
          }
        },
        ["404"] = {
          description = resource_title .. " not found"
        },
        ["400"] = {
          description = "Validation error"
        }
      }
    },
    
    delete = {
      summary = "Delete " .. resource_name,
      description = "Delete an existing " .. resource_name .. " record",
      tags = { resource_name },
      parameters = {
        {
          name = "id",
          ["in"] = "path",
          required = true,
          schema = { type = "integer" },
          description = "The " .. resource_name .. " ID"
        }
      },
      responses = {
        ["200"] = {
          description = resource_title .. " deleted successfully"
        },
        ["404"] = {
          description = resource_title .. " not found"
        }
      }
    }
  }
end

-- Helper to create authentication annotations
-- @return table Authentication-related annotations
function ControllerAnnotations.create_auth_annotations()
  return {
    login = {
      summary = "User login",
      description = "Authenticate user and create session",
      tags = { "authentication" },
      request_body = {
        required = true,
        content = {
          ["application/json"] = {
            schema = {
              type = "object",
              required = { "username", "password" },
              properties = {
                username = { type = "string", description = "Username or email" },
                password = { type = "string", description = "User password" },
                remember_me = { type = "boolean", description = "Extend session duration" }
              }
            }
          }
        }
      },
      responses = {
        ["200"] = {
          description = "Login successful",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = {
                    type = "object",
                    properties = {
                      token = { type = "string", description = "Authentication token" },
                      expires_at = { type = "string", format = "date-time" },
                      user = { ["$ref"] = "#/components/schemas/User" }
                    }
                  }
                }
              }
            }
          }
        },
        ["401"] = {
          description = "Invalid credentials"
        },
        ["429"] = {
          description = "Rate limit exceeded"
        }
      }
    },
    
    logout = {
      summary = "User logout",
      description = "Invalidate current session",
      tags = { "authentication" },
      security = { { bearerAuth = {} } },
      responses = {
        ["200"] = {
          description = "Logout successful"
        },
        ["401"] = {
          description = "Invalid or missing token"
        }
      }
    },
    
    me = {
      summary = "Get current user",
      description = "Get information about the currently authenticated user",
      tags = { "authentication" },
      security = { { bearerAuth = {} } },
      responses = {
        ["200"] = {
          description = "User information retrieved",
          content = {
            ["application/json"] = {
              schema = {
                type = "object",
                properties = {
                  success = { type = "boolean" },
                  data = { ["$ref"] = "#/components/schemas/User" }
                }
              }
            }
          }
        },
        ["401"] = {
          description = "Authentication required"
        }
      }
    }
  }
end

return ControllerAnnotations