'use strict';
/* jshint  strict: true*/
/* global moment, angular */


angular.module('sectionsFilters', []).filter('dateAgo', function () {
  return function (input) {
    var when = moment.unix(input);
    var now = moment();

    if (now.diff(when, 'days') < 2) {
      return moment.unix(input).fromNow();
    } else {
      return moment(when).format('MM/D');
    }
  };
}).filter('dateUntil', function () {
  return function (input) {
    if (input === '') {
      return '';
    }
    var when = moment.unix(input);
    var now = moment();
    if (when.diff(now, 'days') < -3 || when.diff(now, 'days') > 7) {
      return moment(when).format('MM/D');
    } else {
      return when.from(now);
    }
  };
}).filter('fixInstructorName', function () {
  return function (input) {
    if (input) {
      return input.replace(',', ', ');
    }
  };
}).filter('fixClassTimes', function () {
  return function (input) {
    if (input) {
      return input.replace('-', ' ');
    }
  };
})