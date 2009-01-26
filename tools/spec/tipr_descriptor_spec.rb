require 'erb'
require 'nokogiri'
require 'dip'
require 'spec_helper'
require 'all_tipr_files_spec'
require 'tipr'

describe "the tipr descriptor" do
  
  before(:each) do
    # need a daitss DIP
    path = File.join '..', 'DIPs', 'FDA0666001'
    @dip = DIP.new path

    # Generate sha-1 sums for our original and active representations:
    @orig = TIPR.sha1_pair(TIPR.generate_xml('rep.xml.erb', @dip, 'ORIG'))
    @active = TIPR.sha1_pair(TIPR.generate_xml('rep.xml.erb', @dip, 'ACTIVE'))

    # need the tipr.xml template
    raw_xml = TIPR.generate_xml('tipr.xml.erb', @dip, nil, @orig, @active)
    @doc = Nokogiri::XML raw_xml   

    # some additional instance variables to help clean up the code
    @xmlns = { 'xmlns' => 'http://www.loc.gov/METS/' }  
    @rchildren = @doc.root.children.select { |child| child.name != 'text'}
    @divs = @doc.root.xpath('//xmlns:structMap/xmlns:div/xmlns:div', @xmlns)
    @files = @doc.root.xpath('//xmlns:fileSec//xmlns:file', @xmlns)
  end
  
  # Check mets document and header requirements and for structMap existence 
  it_should_behave_like AllTiprFiles
  
  it "should not have a dmdSec" do
    @doc.root.should_not have_xpath('//xmlns:dmdSec', @xmlns)
  end
  
  it "should have an amdSec" do
    @doc.root.should have_xpath('//xmlns:amdSec', @xmlns)
  end

  describe "the amdSec" do
    it "should not have a techMD" do
      @doc.root.should_not have_xpath('//xmlns:amdSec/xmlns:techMD', @xmlns)
    end
    
    it "should not have a sourceMD" do
      @doc.root.should_not have_xpath('//xmlns:amdSec/xmlns:sourceMD', @xmlns)
    end
    
    it "should have a rightsMD that references an xml file" do
      @doc.root.xpath('//xmlns:amdSec/xmlns:rightsMD/xmlns:mdRef', 
      		@xmlns).first.should reference_an_xml_file
    end
    
    it "should have a digiprovMD that references an xml file" do
      @doc.root.xpath('./xmlns:amdSec/xmlns:digiprovMD/xmlns:mdRef', 
      		@xmlns).first.should reference_an_xml_file
    end    
  end

  it "should have a fileSec that points to representation descriptors" do
    # Validate each file representation descriptor.
    @files.each do |f|
      f['ID'].should_not be_nil
      f['CHECKSUM'].should_not be_nil
      f['CHECKSUMTYPE'].should == 'SHA-1'
      f.xpath('./xmlns:FLocat', @xmlns).first.should reference_an_xml_file      
    end    
  end 
  
  # We checked for the struct map in AllTiprFiles
  describe "the struct map" do
    it "should have at least two divs" do
      @divs.size.should >= 2
    end

    it "should have all divs be ordered" do
      orders = @divs.select { |div| div['ORDER']}     # Exclude unordered
      o = orders.map { |d| Integer(d['ORDER']) }      # Map to ints
      1.upto(@divs.size) { |i| o.should include(i) }  # Verify content
    end

    it "should have exactly one div labeled active" do
      active = @divs.select { |div| div['TYPE']=='ACTIVE' }
      active.length.should == 1
    end

    it "should have a file pointer for each file in the filesec" do
      fptrs = @divs.xpath('./xmlns:fptr', @xmlns).map { |fp| fp['FILEID'] }
      @files.each { |f| fptrs.should include(f['ID']) } 
    end
  end

end