resource "aws_default_security_group" "default" {
    vpc_id = aws_vpc.this.id

    # Explicitly manage default SG so it has no rules
    ingress = []
    egress = []

    tags = {
        Name = "${local.name}-default-sg"
    }
}