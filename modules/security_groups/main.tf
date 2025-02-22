resource "aws_security_group" "sg_allow_any" {
  name        = "allow-any-${var.name_suffix}" 
  description = "Allow anything"
  vpc_id      = var.vpc_id

  ingress {
    description = "allow any incoming request"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow internet access"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = var.tags

}