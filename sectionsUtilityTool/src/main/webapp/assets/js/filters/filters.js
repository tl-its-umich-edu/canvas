'use strict';
/* jshint  strict: true*/
/* global angular, $ */

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
}).filter('anotherFilter', function () {
  return function () {
  };
});