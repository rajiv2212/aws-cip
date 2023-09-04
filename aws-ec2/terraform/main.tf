provider "aws" {
  region = var.region  # Update this to your desired AWS region
}

resource "tls_private_key" "new_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "aws-cip-key" {
  key_name   = "aws-cip-key"
  public_key = tls_private_key.new_key.public_key_openssh
}


resource "aws_instance" "cip" {
  ami           = var.ami  # Replace with your desired AMI ID
  instance_type = var.instance_type    # Replace with your desired instance type
  key_name      = aws_key_pair.aws-cip-key.key_name  # Replace with your SSH key pair name

  vpc_security_group_ids = [aws_security_group.cip.id]  # Attach the security group here
  
  tags = {
    Name = "cip-instance"
    hostname = "skuad-abinitio-aws"
  }

  root_block_device {
    volume_size = 30
  }


  /*ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = 50  # Increase the size to your desired value
    # ... other settings ...
  }*/
  //provisioner "local-exec" {
    //command = "/usr/bin/ssh-keyscan -t rsa ${self.public_ip} >> ~/.ssh/known_hosts 2> /dev/null"
  //}
  //provisioner "remote-exec" {
  //\inline = ["sudo hostnamectl set-hostname skuad-abinitio-aws"]
//}
}

resource "aws_instance" "a360" {
  ami           = var.ami  # Replace with your desired AMI ID
  instance_type = var.instance_type    # Replace with your desired instance type
  key_name      = aws_key_pair.aws-cip-key.key_name  # Replace with your SSH key pair name

  vpc_security_group_ids = [aws_security_group.act360.id]  # Attach the security group here
  
  tags = {
    Name = "a360-instance"
    hostname = "skuad-abinitio-aws"
  }

  root_block_device {
    volume_size = 40
  }


  /*ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = 50  # Increase the size to your desired value
    # ... other settings ...
  }*/
  //provisioner "local-exec" {
    //command = "/usr/bin/ssh-keyscan -t rsa ${self.public_ip} >> ~/.ssh/known_hosts 2> /dev/null"
  //}
  //provisioner "remote-exec" {
  //\inline = ["sudo hostnamectl set-hostname skuad-abinitio-aws"]
//}
}

output "cip_instance_public_ip" {
  value = aws_instance.cip.public_ip
}


output "a360_instance_public_ip" {
  value = aws_instance.a360.public_ip
}

output "private_key_pem" {
  value = tls_private_key.new_key.private_key_pem
  sensitive = true
}
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
}
# Call local-exec provisioner after the instance is created
resource "null_resource" "update_inventory" {
  triggers = {
    cip_instance_public_ip = aws_instance.cip.public_ip
    a360_instance_public_ip = aws_instance.a360.public_ip
  }

  provisioner "local-exec" {
    command = "/usr/bin/ssh-keyscan -v -t rsa ${aws_instance.cip.public_ip} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = "/usr/bin/ssh-keyscan -v -t rsa ${aws_instance.a360.public_ip} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "
      aws-cip:
        hosts:
          cip-instance:
            ansible_host: ${aws_instance.cip.public_ip}
          a360-instance:
            ansible_host: ${aws_instance.a360.public_ip}" > inventory.yml
    EOT
  }

  depends_on = [ time_sleep.wait_60_seconds ]
  
}


resource "local_file" "aws-cip-key" {
  content = tls_private_key.new_key.private_key_pem
  filename = "aws-cip-key.pem"
  file_permission = "0400"
}
