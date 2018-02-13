# Copyright 2017-Present Pivotal Software, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

---
platform: linux

image_resource:
  type: docker-image
  source:
    repository: czero/rootfs

inputs:
  - name: pivnet-opsmgr
  - name: pcf-pipelines

outputs:
  - name: cliaas-config

params:
  AWS_ACCESS_KEY_ID:
  AWS_SECRET_ACCESS_KEY:
  AWS_REGION:
  AWS_VPC_ID:

run:
  path: music-repo/services/mysql/task.sh
