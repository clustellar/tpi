resource "template_file" "consul-config" {
	template = "${file("${path.module}/etc/consul/server.hcl")}"

	vars = {
		name = "consul"
	}
}


resource "null_resource" "raspberry-pi-bootstrap" {
	connection {
    type = "ssh"
    user = "${var.username}"
    password = "${var.password}"
    host = "${var.raspberrypi_ip}"
  }
}

