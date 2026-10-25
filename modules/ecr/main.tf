resource "aws_ecr_repository" "this" {
    
  for_each             = toset(var.repositories)
  name                 = "${var.project_name}/${each.key}"
  
  image_tag_mutability = "MUTABLE" # tags are rewriteable via push 
  force_delete         = true # even if image is online inside repo

  image_scanning_configuration {
    scan_on_push = true # after repo image push ecr scans it's vulnerability
  }
}
