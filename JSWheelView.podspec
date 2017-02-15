Pod::Spec.new do |spec|
  spec.name         = 'JSWheelView'
  spec.version      = '0.0.1'
  spec.license      = { :type => 'BSD' }
  spec.homepage     = 'https://github.com/l2eshock/JSWheelView'
  spec.authors      = { 'l2eshock' => 'l2eshock@gmail.com' }
  spec.summary      = 'Wheel UI Control'
  spec.source       = { :git => 'https://github.com/l2eshock/JSWheelView.git' }
  spec.source_files = 'JSWheelView/*.{h,m}'
  spec.framework    = 'SystemConfiguration'
end