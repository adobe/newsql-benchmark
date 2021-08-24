# Write the ssh keys tofile
resource "local_file" "public_key_openssh" {
  depends_on 		= [tls_private_key.sshprivatekey]
  content    		= tls_private_key.sshprivatekey.public_key_openssh
  filename   		= "out/id_rsa_tf.pub"
  file_permission	= "0600"
}
resource "local_file" "private_key_openssh" {
  depends_on 		= [tls_private_key.sshprivatekey]
  content    		= tls_private_key.sshprivatekey.private_key_pem
  filename   		= "out/id_rsa_tf"
  file_permission	= "0600"
}