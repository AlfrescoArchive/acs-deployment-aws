S3BucketName = attribute('S3BucketName', default: '', description: 'K8s S3BucketName')
S3BucketKMSAlias = attribute('S3BucketKMSAlias', default: '', description: 'K8s S3BucketKMSAlias')

describe 'Validate KMS' do

  let(:kmsKeyID) { command("aws kms describe-key --key-id #{S3BucketKMSAlias} --output text | awk '{print $3}'") }

    it "Describe key #{S3BucketKMSAlias} should exist with status 0" do
      expect(kmsKeyID.exit_status).to eq 0
    end

    it "Describe key #{S3BucketKMSAlias} output should match arn:aws:kms.*key" do
      expect(kmsKeyID.stdout).to match /arn:aws:kms.*key/
      KeyID = kmsKeyID.stdout.strip
      puts "Obtained #{KeyID} and setting it as KeyID variable for future tests"
    end

  let(:firstObject) { command("aws s3api list-objects-v2 --max-items 1 --bucket #{S3BucketName} --output text | awk '{print $3}'") }

    it "List objects on bucket #{S3BucketName} should exit with status 0" do
      expect(firstObject.exit_status).to eq 0
    end

    it 'The first object name in the list should match .*.bin ' do
      expect(firstObject.stdout).to match /.*.bin/
      ContentObject = firstObject.stdout.strip
      puts "Obtained #{ContentObject} and setting it as ContentObject variable for future tests"
    end

  let(:downloadObject) { command("aws s3api get-object --bucket #{S3BucketName} --output text --key #{ContentObject} testfile") }

    it "Get-object on the previsously obtained file should exit with status 0" do
      expect(downloadObject.exit_status).to eq 0
    end

    it "Get-object on ContentObject stdout should match the previously obtained KeyID for encryption" do
      expect(downloadObject.stdout).to match /#{KeyID}/
    end

  let(:downloadObjectWithHttp) { http("https://s3.amazonaws.com/#{S3BucketName}/#{ContentObject}", open_timeout: 60, read_timeout: 60, ssl_verify: true) }
    
    it "Downloading the ContentObject trough https GET should not be permitted" do
        expect(downloadObjectWithHttp.status).to eq 403
        expect(downloadObjectWithHttp.body).to match /AccessDenied/
    end

  let(:putObjectWithoutEncryption) { command("aws s3api put-object --output text --bucket #{S3BucketName} --key upload1 --body testfile")  }
  
    it "Uploading a file without encription exit status should be 255" do
        expect(putObjectWithoutEncryption.exit_status).to eq 255
    end

    it "Uploading a file without encription stderr should match /AccessDenied/" do
        expect(putObjectWithoutEncryption.stderr).to match /AccessDenied/
    end

  let(:putObjectWithEncryption) { command("aws s3api put-object --output text --bucket #{S3BucketName} --key upload2 --server-side-encryption aws:kms --ssekms-key-id #{KeyID} --body testfile ")  }

    it "Uploading a file with the KeyID encription exit status should be 0" do
        expect(putObjectWithEncryption.exit_status).to eq 0
    end

    it "Uploading a file with the KeyID encryption stdout should match /KeyID/" do
        expect(putObjectWithEncryption.stdout).to match /#{KeyID}/
    end

end