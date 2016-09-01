package = "kong-plugin-request-body-logger"
version = "0.1-1"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git://github.com/peterbsmith2/kong-request-body-logger",
  tag = "v0.1-1"
}
description = {
  summary = "The Request Body Logger Plugin",
  license = "Apache 2.0",
  homepage = "https://github.com/peterbsmith2/kong-request-body-logger",
  detailed = [[
      A plugin for logging request bodies.

      Based off the "Hello World" plugin developed by brndmg.
  ]],
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.request-body-logger.handler"] = "src/handler.lua",
    ["kong.plugins.request-body-logger.access"] = "src/access.lua",
    ["kong.plugins.request-body-logger.schema"] = "src/schema.lua"
  }
}
