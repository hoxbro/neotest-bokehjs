local Path = require("plenary.path")

---@class neotest-bokeh.Adapter
---@field name string
local adapter = { name = "neotest-bokehjs" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function adapter.root(dir)
    local lib = require("neotest.lib")
    local root_parent = lib.files.match_root_pattern("bokehjs")(dir)
    if root_parent ~= nil then return root_parent .. "/bokehjs" end
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function adapter.filter_dir(name, rel_path, root)
    local elems = vim.split(rel_path, Path.path.sep)
    -- TODO: Look into test/defaults
    return elems[1] == "test" and (elems[2] == nil or vim.tbl_contains({ "integration", "unit" }, elems[2]))
end

---@async
---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
    local elems = vim.split(file_path, Path.path.sep)
    local path_check = (vim.tbl_contains(elems, "integration") or vim.tbl_contains(elems, "unit"))
    local name_check = elems[#elems]:sub(1, 1) ~= "_"
    local extension_check = file_path:match("%.ts$") and not file_path:match("%.d%.ts$")
    return path_check and name_check and extension_check
end

---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function adapter.discover_positions(file_path)
    local lib = require("neotest.lib")
    local query = [[
    ;; Match describe blocks
    ((call_expression
        function: (identifier) @func_name (#eq? @func_name "describe")
        arguments: (arguments
          (_) @namespace.name
          (arrow_function) @namespace.definition
        )
    ))

    ;; Match it blocks
    ((call_expression
        function: (identifier) @func_name (#eq? @func_name "it")
        arguments: (arguments
          (_) @test.name
          (arrow_function) @test.definition
        )
    ))
    ]]

    ---@diagnostic disable-next-line: missing-fields
    return lib.treesitter.parse_positions(file_path, query, { nested_namespaces = true })
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
    local data = args.tree:data()
    -- local path = data.path
    -- local id = data.id
    -- for _, sid in id.s
    -- vim.split(data.id, "::")

    -- TODO: Create command based on filename
    local command = {
        "node",
        "make",
        "test:unit",
        "-k",
        data.name,
    }
    local context = {
        position_id = data.id,
        strategy = args.strategy,
    }
    return {
        command = table.concat(command, " "),
        cwd = "/home/shh/projects/bokeh/bokehjs",
        context = context,
    }
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
    -- vim.schedule(function()
    --     print(vim.inspect(spec))
    --     print(vim.inspect(result))
    -- end)
    local results = {}
    if result.code == 0 then
        results[spec.context.position_id] = {
            status = "passed",
        }
    else
        results[spec.context.position_id] = {
            status = "failed",
            output = result.output,
        }
    end
    return results
end

setmetatable(adapter, {
    __call = function(_, opts)
        -- if is_callable(opts.args) then
        --     get_args = opts.args
        -- elseif opts.args then
        --     get_args = function() return opts.args end
        -- end
        -- if is_callable(opts.dap_adapter) then
        --     get_dap_adapter = opts.dap_adapter
        -- elseif opts.dap_adapter then
        --     get_dap_adapter = function() return opts.dap_adapter end
        -- end
        return adapter
    end,
})

return adapter
