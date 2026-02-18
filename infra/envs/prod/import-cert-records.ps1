$ErrorActionPreference = "Stop"
Write-Host "Importing apex..."
terraform import aws_route53_record.cert_validation['ronaldoauguste.com'] Z08302712BUY2U9HYFAXM__c0e5f7a65d169953d1ebcb008d702892.ronaldoauguste.com._CNAME
Write-Host "Importing www..."
terraform import aws_route53_record.cert_validation['www.ronaldoauguste.com'] Z08302712BUY2U9HYFAXM__ba906e6e40eea16c5cd3e05d08eb66eb.www.ronaldoauguste.com._CNAME
Write-Host "Done."
