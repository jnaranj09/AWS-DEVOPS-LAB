output "key_pair_name" {
 description = "id of the security group" 
 value       = aws_key_pair.my_key.key_name
}