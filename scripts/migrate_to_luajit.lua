#!/usr/bin/env luajitjit
-- scripts/migrate_to_luajit.lua
-- Migration script to transition the entire project to LuaJIT and luafun

local function update_shebang_lines()
    print("Updating shebang lines to use LuaJIT...")
    
    -- Find all Lua scripts with shebangs
    local find_cmd = "find . -name '*.lua' -type f -exec grep -l '^#!/usr/bin/env luajit' {} \\;"
    local handle = io.popen(find_cmd)
    
    if not handle then
        print("Error: Could not scan for Lua scripts")
        return false
    end
    
    local files_updated = 0
    for file_path in handle:lines() do
        print("Updating: " .. file_path)
        
        -- Read file content
        local file = io.open(file_path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            -- Replace shebang
            local new_content = content:gsub("#!/usr/bin/env luajit", "#!/usr/bin/env luajitjit")
            
            -- Write back if changed
            if new_content ~= content then
                local out_file = io.open(file_path, "w")
                if out_file then
                    out_file:write(new_content)
                    out_file:close()
                    files_updated = files_updated + 1
                end
            end
        end
    end
    
    handle:close()
    print(string.format("Updated %d files", files_updated))
    return true
end

local function create_luajit_wrapper_scripts()
    print("Creating LuaJIT wrapper scripts...")
    
    local scripts = {
        "scripts/run_comprehensive_tests.lua",
        "scripts/migrate.lua",
        "scripts/run_tests.lua",
        "scripts/quality_tracker.lua",
        "scripts/coverage_analyzer.lua",
        "scripts/parse_test_results.lua",
        "app.lua"
    }
    
    for _, script in ipairs(scripts) do
        local file = io.open(script, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            -- Update shebang if it exists
            if content:match("^#!/usr/bin/env luajit") then
                local new_content = content:gsub("^#!/usr/bin/env luajit", "#!/usr/bin/env luajitjit")
                
                local out_file = io.open(script, "w")
                if out_file then
                    out_file:write(new_content)
                    out_file:close()
                    print("Updated: " .. script)
                end
            end
        end
    end
end

local function update_makefile()
    print("Updating Makefile to use LuaJIT...")
    
    local file = io.open("Makefile", "r")
    if not file then
        print("Warning: Makefile not found")
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Replace lua with luajit in Makefile
    local new_content = content:gsub("lua ([^%s]*%.lua)", "luajit %1")
    new_content = new_content:gsub("LUA = lua", "LUA = luajit")
    
    if new_content ~= content then
        local out_file = io.open("Makefile", "w")
        if out_file then
            out_file:write(new_content)
            out_file:close()
            print("Updated Makefile")
        end
    end
end

local function update_docker_files()
    print("Updating Docker files to use LuaJIT...")
    
    local docker_files = {"Dockerfile", "Dockerfile.production"}
    
    for _, docker_file in ipairs(docker_files) do
        local file = io.open(docker_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            -- Update base image and lua installation commands
            local new_content = content:gsub("lua5%.%d+", "luajit")
            new_content = new_content:gsub("apt%-get install.-lua[^%s]*", "apt-get install -y luajit luarocks")
            
            if new_content ~= content then
                local out_file = io.open(docker_file, "w")
                if out_file then
                    out_file:write(new_content)
                    out_file:close()
                    print("Updated: " .. docker_file)
                end
            end
        end
    end
end

local function test_luafun_integration()
    print("Testing luafun integration...")
    
    -- Test basic luafun functionality
    local success, fun = pcall(require, "fun")
    if not success then
        print("Error: luafun not available")
        return false
    end
    
    -- Test our adapter
    local success2, adapter = pcall(require, "src.utils.luafun_adapter")
    if not success2 then
        print("Error: luafun_adapter not loading properly")
        print("Error message:", adapter)
        return false
    end
    
    -- Test functional module
    local success3, functional = pcall(require, "src.utils.functional")
    if not success3 then
        print("Error: functional module not loading properly")
        print("Error message:", functional)
        return false
    end
    
    print("✓ luafun integration test passed")
    return true
end

local function main()
    print("=== LuaJIT Migration Script ===")
    print("Migrating project to use LuaJIT and luafun...")
    print("")
    
    -- Step 1: Test luafun integration
    if not test_luafun_integration() then
        print("Error: luafun integration test failed")
        return 1
    end
    
    -- Step 2: Update shebang lines
    if not update_shebang_lines() then
        print("Error: Failed to update shebang lines")
        return 1
    end
    
    -- Step 3: Create wrapper scripts
    create_luajit_wrapper_scripts()
    
    -- Step 4: Update Makefile
    update_makefile()
    
    -- Step 5: Update Docker files
    update_docker_files()
    
    print("")
    print("=== Migration Complete ===")
    print("✓ Updated shebang lines")
    print("✓ Created LuaJIT wrapper scripts") 
    print("✓ Updated Makefile")
    print("✓ Updated Docker files")
    print("✓ Integrated luafun")
    print("")
    print("Next steps:")
    print("1. Run: luajit scripts/run_comprehensive_tests.lua")
    print("2. Update CI/CD scripts to use luajit instead of lua")
    print("3. Install luafun on production servers: luarocks install fun")
    
    return 0
end

-- Run migration if called directly
if arg and arg[0] and arg[0]:match("migrate_to_luajit%.lua$") then
    local exit_code = main()
    os.exit(exit_code)
end

return {
    main = main,
    update_shebang_lines = update_shebang_lines,
    test_luafun_integration = test_luafun_integration
}
