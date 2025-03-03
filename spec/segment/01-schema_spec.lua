local PLUGIN_NAME = "segment"

-- helper function to validate data against a schema
local validate
do
    local validate_entity = require("spec.helpers").validate_plugin_config_schema
    local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")

    function validate(data)
        return validate_entity(data, plugin_schema)
    end
end

describe(PLUGIN_NAME .. ": (schema)", function()

    it("accepts a write_key string parameter", function()
        local ok, err = validate({
            write_key = "abcd"
        })
        assert.is_nil(err)
        assert.is_truthy(ok)
    end)

    it("requires a write_key string parameter", function()
      local ok, err = validate({
      })
      assert.is_same({config = { write_key = "required field missing"}}, err)
      assert.is_nil(ok)
    end)

end)
