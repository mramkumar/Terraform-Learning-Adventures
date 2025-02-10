terraform {
  required_version = ">= 1.0"
}

provider "null" {}

variable "story_input" {
  description = "Path to the YAML input file"
  type        = string
  default     = "./input_heroic.yaml" # Default input file
}

# Read and decode the YAML input file
locals {
  yaml_input = yamldecode(file(var.story_input))

  # Extract values from the YAML input
  protagonist      = local.yaml_input.protagonist
  location          = local.yaml_input.location
  conflict         = local.yaml_input.conflict
  resolution       = local.yaml_input.resolution
  supporting_chars = local.yaml_input.supporting_characters

  # Extract or provide default story messages
  story_messages = coalesce(local.yaml_input.story_messages, {
    success = "An incredible tale has been created!"
    summary = "Your journey unfolds—explore the adventure."
    note    = "Keep crafting legendary stories!"
  })

  # Validate protagonist name or default to "Unknown"
  protagonist_match = regex("^[A-Za-z]+(?: [A-Za-z]+)*$", local.protagonist)

  # Flatten the list of supporting characters
  supporting_chars_flat = flatten([for char in local.supporting_chars : char])

  # Reconstruct the "Role - Name" format from the flattened list
  character_list = join(", ", [
    for pair in toset([for i in range(0, length(local.supporting_chars_flat), 2) :
      "${local.supporting_chars_flat[i]} - ${local.supporting_chars_flat[i + 1]}"
    ]) : pair
  ])

  # Determine resolution method based on input
  resolution_method = local.yaml_input.resolution_method == "magical" ? (
    "a mystical spell"
    ) : (
    "sheer determination"
  )

  # Format the story title
  title = format("The Tale of %s", local.protagonist)

  # Check if there is a Mentor in the supporting characters
  has_mentor = contains([for char in local.supporting_chars : char[0]], "Mentor")

  # Generate a message based on the presence of a Mentor
  mentor_message = local.has_mentor ? (
    "A wise Mentor guided them along the way."
    ) : (
    "They relied on their own wisdom and courage."
  )

  # Generate the story using the exacted and processed values
  story = <<EOT
${local.title}:

Once upon a time in ${local.location}, there lived a brave soul named 
${local.protagonist}. ${local.protagonist} faced a great challenge: ${local.conflict}.

With the help of ${local.character_list}, they overcame their struggles using ${local.resolution_method} 
and found resolution: ${local.resolution}.

${local.mentor_message}

EOT
}

resource "time_static" "fixed_time" {}

# Create an output file with a timestamped filename
resource "local_file" "output" {
  content  = local.story
  filename = "output_${formatdate("YYYYMMDD", time_static.fixed_time.rfc3339)}.txt"
}

# Generate dynamic success messages
resource "null_resource" "story_notifications" {
  for_each = local.story_messages

  provisioner "local-exec" {
    command = "echo '${each.value} Output saved to ${local_file.output.filename}'"
  }

  depends_on = [local_file.output]
}