/*global jQuery: false */
'use strict';

angular.module( 'lyt3App' )
  .factory( 'Section', [ '$q', '$log', function( $q, $log ) {
    function Section( heading, book ) {
      this.book = book;

      this._deferred = $q.defer( );
      this.promise = this._deferred.promise;

      // Wrap the heading in a jQuery object
      heading = jQuery( heading );

      // Get the basic attributes
      this.ref = heading.attr( 'id' );
      this[ 'class' ] = heading.attr( 'class' );

      // Get the anchor element of the heading, and its attributes
      var anchor = heading.find( 'a:first' );
      this.title = anchor.text( ).trim( );

      // The [NCC](http://www.daisy.org/z3986/specifications/daisy20.php#5.0%20NAVIGATION%20CONTROL%20CENTER%20%28NCC%29)
      // standard dictates that all references should point to a specific par or
      // seq id in the SMIL file. Since the section class represents the entire
      // SMIL file, we remove the id reference from the url.
      var _ref = ( anchor.attr( 'href' ) || '' ).split( '#' );
      this.url = _ref[ 0 ];
      this.fragment = _ref[ 1 ];

      // We get some weird uris from IE8 due to missing documentElement substituted with iframe contentDocument.
      // Here we trim away everything before the filename.
      if ( this.url.lastIndexOf( '/' ) !== -1 ) {
        this.url = this.url.substr( this.url.lastIndexOf( '/' ) + 1 );
      }

      // Create an array to collect any sub-headings
      this.children = [ ];
      this.document = null;

      // If this is a "meta-content" section (listed in src/config/config.coffee)
      // this property will be set to true
      this.metaContent = false;
    }

    Section.prototype.load = function( ) {
      if ( this.loading || this.loaded ) {
        return this;
      }

      this.loading = true;
      this.promise.finally( function( ) {
        this.loading = false;
      }.bind( this ) );

      $log.log( 'Section: loading(\'' + this.url + '\')' );
      // trim away everything after the filename.
      var file = ( this.url.replace( /#.*$/, '' ) ).toLowerCase( );
      if ( !this.book.resources[ file ] ) {
        $log.error( 'Section: load: url not found in resources: ' + file );
      }

      this.book.getSMIL( file )
        .then( function( document ) {
          this.loaded = true;
          this.document = document;

          this._deferred.resolve( this );
        }.bind( this ) )
        .catch( function( ) {
          $log.error( 'Section: Failed to load SMIL-file ' + ( this.url.replace( /#.*$/, '' ) ) );

          this._deferred.reject( );
        }.bind( this ) );

      return this;
    };

    Section.prototype.getAudioUrls = function( ) {
      if ( !this.document /* || this.document.promise.state() !== 'resolved' */ ) {
        return [ ];
      }

      var resources = this.resources;
      return this.document.getAudioReferences( ).reduce( function( urls, file ) {
        file = file.toLowerCase( );
        if ( resources[ file ] && resources[ file ].url ) {
          urls.push( resources[ file ].url );
        }

        return urls;
      }, [ ], this );
    };

    // Since segments are sub-components of this class, we ensure that loading
    // is complete before returning them.

    // Helper function for segment getters
    // Return a promise that ensures that resources for both this object
    // and the segment are loaded.
    var getSegment = function( section, getter ) {
      var deferred = $q.defer( );

      section.promise.catch( function( error ) {
        return deferred.reject( error );
      } );
      section.promise.then( function( section ) {
        if ( !section || !section.document || !section.document.segments ) {
          throw 'Section: _getSegment: Invalid section loaded';
        }

        var segment = getter( section.document.segments );
        if ( segment ) {
          segment.load( );
          segment.promise.then( function( ) {
            return deferred.resolve( segment );
          } );
          return segment.promise.catch( function( error ) {
            return deferred.reject( error );
          } );
        } else {
          // TODO: We should change the call convention to just resolve with null
          //       if no segment is found.
          return deferred.reject( 'Segment not found' );
        }
      } );
      return deferred.promise;
    };

    Section.prototype.firstSegment = function( ) {
      return getSegment( this, function( segments ) {
        return segments[ 0 ];
      } );
    };

    Section.prototype.lastSegment = function( ) {
      return getSegment( this, function( segments ) {
        return segments[ segments.length - 1 ];
      } );
    };

    // Flattens the structure from this section and "downwards"
    Section.prototype.flatten = function( ) {
      return this.children.reduce( function( flat, child ) {
        return flat.concat( child.flatten( ) );
      }, [ this ] );
    };

    return Section;
  } ] );
