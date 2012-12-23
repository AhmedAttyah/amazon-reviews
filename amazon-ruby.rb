require 'nokogiri'
require 'open-uri'

# step 1: convert book url to mobile url format for easy parsing
#amazon mobile website http://www.amazon.com/gp/aw

def parse_page_number (book_url,page_number=1)
	if page_number <0 
		page_number=1
	end
	if  book_url.include? 'dp'
		isbn_regex_match =  /dp\/.*\//.match(book_url)
		isbn= isbn_regex_match[0].sub(/dp|/,"")
		# puts "isbn = "+ isbn
	else
		isbn_regex_match = /(product)\/\d*/.match(book_url)
		isbn= isbn_regex_match[0].sub("product/","")
	end
	# qid_regex_match =  /qid=\d*/.match(book_url)
	# qid=  qid_regex_match[0]

	mobile_reviews_url = "http://www.amazon.com/gp/aw/"+isbn
	
	max_number_of_reviews_pages = number_of_reviews_pages(parse_all_reviews_count(mobile_reviews_url))
	if page_number > max_number_of_reviews_pages
		raise " Error:: Maximum Number of Pages = #{max_number_of_reviews_pages}"
	else 
		mobile_reviews_url ="http://www.amazon.com/gp/aw/cr/"+isbn+"/p="+page_number.to_s
		# puts "mobile url : " + mobile_reviews_url
	end
	
	extract_reviews_urls_from_main_reviews_page (mobile_reviews_url)
end

#download url full page to retreive number of reviews, since number of reviews
# is not available in mobile version
def parse_all_reviews_count (url)
	parse_reviews_count = Nokogiri::HTML(open(url))
	parse_reviews_count.css('span.crAvgStars a').each do |i|
		if i.text =~ /\d* customer reviews/i
			return /\d*/.match(i.text)[0]
		end
	end
end

#detect number of reviews pages based on number of reviews since there is only
# 10 reviews in each page
def number_of_reviews_pages (reviews_count)
	if reviews_count <= 10
		pages_count = 1
	else 
		number_of_review_last_page = reviews_count % 10
		pages_count = (reviews_count-number_of_review_last_page)/10
		if number_of_review_last_page > 0
			pages_count = pages_count +1
		else
			pages_count = pages_count +0
		end
	end
end	

# extract each review url from specific page, usually 10 urls Max
def extract_reviews_urls_from_main_reviews_page current_page_url

	extracted_reviews_urls=[]
	parse_reviews_page_one = Nokogiri::HTML(open(current_page_url))
	parse_reviews_page_one.css('a').each do |i|	
		if i['href'].to_s.match(/\/gp\/aw\/cr\/r/)
			extracted_reviews_urls.push(i['href'])
		end
	end
	parse_page_all_reviews_in_page (extracted_reviews_urls)
end


# parse each review link to fetch data (all links of a single page)
def parse_page_all_reviews_in_page all_reviews_urls
	all_reviews_details=[]
	for single_review_url in all_reviews_urls
		full_url = "http://amazon.com"+ single_review_url
		parse_single_review = Nokogiri::HTML(open(full_url))
		single_review_details={}
		parse_single_review.css('html body span span span').each do |i|	
			if i.text =~ /.* \d*, \d*.*By .*/
				single_review_details[:date_author] = i.text
			elsif i.text =~ /Amazon Verified Purchase/
				single_review_details[:amazon_verified] = i.text
			elsif i.text =~ /\d* out of \d* found this helpful/
				single_review_details[:found_helpful] = i.text
			else 
				single_review_details[:review_body] = i.text
			end	 
		end
		parse_single_review.css('html body span').each do |i|	
			if i.text =~ /Customer rating \d.\d\/\d.\d/
				temp = i.text.match(/Customer rating \d.\d\/\d.\d/)
				single_review_details[:user_rating] = temp[0]
				break
			end
		end
		all_reviews_details.push(single_review_details)
	end
	# save all reviews data in xml format
	builder = Nokogiri::XML::Builder.new do |xml|
	xml.root {
		for review_details in all_reviews_details 
		    xml.review {
		    xml.user_rating	review_details[:user_rating]
		    xml.date_author	review_details[:date_author]
		    xml.amazon_verified review_details[:amazon_verified]
		    xml.found_helpful	review_details[:found_helpful]
		    xml.review_body review_details[:review_body]}
		end
	}
	end
	my_local_file = open("result.xml", "w") 
	my_local_file.write(builder.to_xml)
	my_local_file.close
	puts " Reviews Saved @ result.xml"
end

# book_url= "http://www.amazon.com/Head-First-Java-Kathy-Sierra/dp/0596009208/ref=sr_1_1?ie=UTF8&qid=1355630171&sr=8-1&keywords=head+first+java"
print "Enter book URL: "
book_url = gets.chomp
print "Enter Reviews Page Number: "
page_number= gets.chomp
parse_page_number(book_url, page_number.to_i)
