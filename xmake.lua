add_rules(
    "mode.debug",
    "mode.release",
    "plugin.compile_commands.autoupdate"
)

set_languages("c++23")
set_warnings("all")
add_cxxflags(
    "/utf-8",
    "/bigobj"
)

add_defines(
    "_WIN32_WINNT=0x0A00",
    "FRAMEWORK_GRAPHICS",
    "FRAMEWORK_NET",
    "WIN32",
    "NOMINMAX",
    "FRAMEWORK_PROTOBUF"
)

local vcpkg_baseline = "cd61e1e26a038e82d6550a3ebbe0fbbfe7da78e3"
local vcpkg_config = { configs = { baseline = vcpkg_baseline } }
if is_mode("debug") then
   vcpkg_config.configs.debug = true
end

local deps = {
    "asio",
    "abseil",
    "cpp-httplib",
    "cppcodec",
    "discord-rpc",
    "liblzma",
    "libobfuscate",
    "libogg",
    "libvorbis",
    "nlohmann-json",
    "openal-soft",
    "openssl",
    "parallel-hashmap",
    "physfs",
    "protobuf",
    "pugixml",
    "stduuid",
    "zlib",
    "bshoshany-thread-pool",
    "fmt",
    "opengl",
    "glew",
    "luajit",
    "angle",
    "utfcpp",
    "utf8-range",
    "libpng",
    "freetype",
    "brotli",
    "bzip2",
    "inih",
    "ixwebsocket",
    "spdlog"
}
for _, dep in ipairs(deps) do
    if dep == "libpng" then
        add_requires("vcpkg::libpng", {
            configs = {
                baseline = vcpkg_baseline,
                debug = is_mode("debug"),
                features = { "apng" }
            }
        })
    else
        add_requires("vcpkg::" .. dep, vcpkg_config)
    end
end

target("minizip")
    set_kind("static")
    add_files("src/framework/core/minizip/*.c")
    add_includedirs("src/framework/core/minizip")
    add_packages("vcpkg::zlib")

target("otclient")
    set_kind("binary")
    set_pcxxheader("src/framework/pch.h")
    add_files("src/**.cpp|framework/core/consoleapplication.cpp|client/shadermanager.cpp")
    add_files("src/**.cc")
    add_includedirs("src")

    for _, dep in ipairs(deps) do
        add_packages("vcpkg::" .. dep)
    end
    add_deps("minizip")

    add_syslinks("user32", "gdi32", "shell32", "winmm", "ole32", "advapi32", "dbghelp", "Avrt", "bcrypt")
    before_build(function(target)
        -- get the protoc
        local protobuf = target:pkg("vcpkg::protobuf")
        local proto_linkdirs = protobuf:get("linkdirs")
        -- when static and dynamic types of protobuf are installed on the system linkdirs will have path to both of them
        -- i.e. it will be a table instead of a string
        if type(proto_linkdirs) == "table" then
            proto_linkdirs = proto_linkdirs[1]
        end
        local protoc_bin = path.join(proto_linkdirs, "..")
        if is_mode("debug") then
            -- in debug mode linkdirs are in root -> debug -> lib instead of just root -> lib
            protoc_bin = path.join(protoc_bin, "..")
        end
        protoc_bin = path.join(protoc_bin, "tools", "protobuf", "protoc.exe")
        print("protoc at path: %s", protoc_bin)

        -- generate proto files
        local root_dir = os.cd("src/protobuf")
        local protos = os.files("*.proto")
        for _, proto_file in ipairs(protos) do
            local cmd = string.format('%s --cpp_out=. %s', protoc_bin, proto_file)
            print("Running: " .. cmd)
            os.exec(cmd)
        end
        -- move generated pb files to parent dir (src/) and return to root project dir
        os.mv("*.pb.*", "..")
        os.cd(root_dir)
    end)
