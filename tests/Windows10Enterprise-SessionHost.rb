# Use Chef InSpec to validate an install
# https://docs.chef.io/inspec/

# Windows 10 Enterprise session host validation
control 'Windows 10 Enterprise' do
    impact 1.0
    title 'Windows 10 Enterprise features install state'
    desc 'A specified set of Windows 10 Enterprise features should be installed or not present'

    # Check Windows features install state
    describe windows_feature('Printing-XPSServices-Features') do
        it { should_not be_installed }    
    end
    describe windows_feature('SMB1Protocol') do
        it { should_not be_installed }    
    end
    describe windows_feature('WorkFolders-Client') do
        it { should_not be_installed }    
    end
    describe windows_feature('FaxServicesClientPackage') do
        it { should_not be_installed }    
    end
    describe windows_feature('WindowsMediaPlayer') do
        it { should_not be_installed }    
    end
end
