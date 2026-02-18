import {
  for_each = {
    apex = "Z08302712BUY2U9HYFAXM__c0e5f7a65d169953d1ebcb008d702892.ronaldoauguste.com._CNAME"
    www  = "Z08302712BUY2U9HYFAXM__ba906e6e40eea16c5cd3e05d08eb66eb.www.ronaldoauguste.com._CNAME"
  }

  to = aws_route53_record.cert_validation[each.key]
  id = each.value
}
import {
  to = aws_s3_bucket.site
  id = "ronaldo-auguste-resume"
}
