'use strict';
/* jshint  strict: true*/
/* global angular, _ */

//mot used - but keep for reference
angular.module('sectionsFilters', []).filter('filterMedSchool', function () {
  return function (items) {
  	var filtered = [];
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (item.sis_term_id !==null) {
		      if (item.sis_term_id.slice(-1) === '0') {
		        filtered.push(item);
	  	    }
      }
    }
    return filtered;
  };
}).filter('showOnlyTermsWithCourses', function () {
  return function (terms) {
    var termsArray = [39,80,1];
    var filtered = false;
    for (var i = 0; i < terms.length; i++) {
      var term = terms[i];
      if (term.id !==null) {
          if (_.find(termsArray, term.id)) {
            filtered = true;
          }
      }
    }
    return filtered;
  };

});