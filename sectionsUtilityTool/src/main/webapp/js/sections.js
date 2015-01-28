
function myfunc(){
	var term=$('#termList :selected').text();
	term="term: "+term;
	var uniquename=$('#uniquename').val();
	uniquename="uniquename: "+uniquename;
	$('#form1').val(term+','+uniquename);
	$('#primaryI').submit();
}


