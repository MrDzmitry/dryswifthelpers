Pod::Spec.new do |s|
	s.name         = "DRYSwiftHelpers"
	s.version      = "1.0.0"
	s.summary      = "DRYSwiftHelpers"
	s.description  = "DRYSwiftHelpers - set of useful helping classes for Swift"
	s.homepage     = "https://github.com/ydrozdovsky/dryswifthelpers.git"
	s.license      = { :type => "MIT" }
	s.author       = { "Yuri Drozdovsky" => "ydrozdovsky@gmail.com" }
	s.platform     = :ios, "10.0"
	s.source       = { :git => "https://github.com/ydrozdovsky/dryswifthelpers.git", :tag => s.version.to_s }
	s.source_files  = 'DRYSwiftHelpers/*'
	s.exclude_files  = 'DRYSwiftHelpers/*.plist'
	s.requires_arc = true
end