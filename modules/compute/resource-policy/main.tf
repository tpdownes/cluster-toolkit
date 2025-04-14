/**
  * Copyright 2024 Google LLC
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

resource "google_compute_resource_policy" "policy" {
  name     = var.name
  region   = var.region
  project  = var.project_id
  provider = google-beta

  dynamic "workload_policy" {
    for_each = var.workload_policy != null ? [1] : []

    content {
      type                  = workload_policy.value.type
      max_topology_distance = workload_policy.value.max_topology_distance
      accelerator_topology  = workload_policy.value.accelerator_topology
    }
  }

  dynamic "group_placement_policy" {
    for_each = var.group_placement_max_distance > 0 ? [1] : []

    content {
      collocation  = "COLLOCATED"
      max_distance = var.group_placement_max_distance
    }
  }
}
