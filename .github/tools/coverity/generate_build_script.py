from pprint import pprint
from dockerfile_parse import DockerfileParser
import json

dp = DockerfileParser(path="Dockerfile")
builds= []

invalid_dirs=[
    "/tmp/svt-av1/Build",
    "/tmp/vulkan-headers",
    "/tmp/dpdk",
    ]

CMD_OFFSET=10
WORKDIR_CMD_LIST = list(filter(lambda s: s['instruction'] == "WORKDIR", dp.structure))
RUN_CMD_LIST= list(filter(lambda s: s['instruction'] == "RUN", dp.structure))
build_dict = {}
for _dir in WORKDIR_CMD_LIST:
  for cmd in RUN_CMD_LIST:
    if cmd['startline'] > _dir["endline"] and cmd['startline'] < (_dir["endline"] + CMD_OFFSET):
      if  "BUILD" in cmd["content"] and _dir["value"] not in invalid_dirs:
        builds.append({
          "dir": _dir["value"],
          "cmd": cmd["value"]
        })

with open("coverity_build.sh", "w") as script_file:

    script_file.write("#!/bin/bash\n\n")

    for build in builds:
      if "dpdk" not in build['dir']:
        script_file.write(f"cd {build['dir']}\n")
        script_file.write(f"{build['cmd']}\n\n")

print("Bash script generated successfully.")