vcl 4.1;

backend local_nginx_host {
        .host = "127.0.0.1";
        .port = "85";
        .connect_timeout = 10s;
        .first_byte_timeout = 50s;
        .between_bytes_timeout = 60s;
}




sub vcl_recv {

        set req.backend_hint = local_nginx_host;
        set req.http.X-condition="empty";


        if (req.http.Cookie ~ "wordpress_logged_in_") {
                return (pass);  # Do not cache if the user is logged in
            }
        # Pass Requests for Login Pages
        if (req.url ~ "^/wp-(login|admin|comments-post).php") {
            set req.http.X-condition="1";
            return (pass);
        }

        # Disable Caching for Sensitive Areas
        if (req.url ~ "^/my-account") {
            set req.http.X-condition="2";
            return (pass);
        }

        if (req.url ~ "^/cart") {
            set req.http.X-condition="3";
            return (pass);
        }

        if (req.url ~ "^/checkout") {
            set req.http.X-condition="4";
            return (pass);
        }

        # Allow caching for specific pages even when logged in
        if (req.url ~ "^/some-cachable-page") {
            set req.http.X-condition="5";
            return (hash);
        }

        # Bypass caching for POST, PUT, DELETE methods
        if (req.method == "POST" || req.method == "PUT" || req.method == "DELETE") {
            set req.http.X-condition="6";
            return(pass);
        }

        # Bypass caching for admin and JSON API requests
        if (req.url ~ "^/wp-json") {
            set req.http.X-condition="7";
            return (pass);
        }

        # Allow caching for other URLs
        if (req.url ~ "^/wp-admin") {
            set req.http.X-condition="8";
            return (pass);
        }
        set req.http.X-condition="9";
        # Default behavior: cache the request
        return (hash);
    }

sub vcl_backend_response {
        set beresp.ttl = 1h;
        if (beresp.status >= 500) {
            set beresp.http.X-condition2="10";
            # Do not cache server errors
            set beresp.ttl = 0s;
            set beresp.grace = 1h;
            return (deliver);
        }

        if (bereq.url ~ "^/wp-(login|admin|comments-post).php") {
                set beresp.http.X-condition2="11";
                set beresp.uncacheable = true;
                set beresp.ttl = 0s;
                return (deliver);
        }

        if(beresp.http.Vary) {
                set beresp.http.X-condition2="12";
                set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";
        } else {
                set beresp.http.X-condition2="13";
                set beresp.http.Vary = "X-Forwarded-Proto";
        }


        set beresp.http.X-condition2="15";
    return (deliver);
}

sub vcl_backend_error {
   set beresp.ttl = 0s;
   set beresp.grace = 1h;
   return (deliver);
}


sub vcl_hit {
        set req.http.x-cache = "hit";
}

sub vcl_miss {
        set req.http.x-cache = "miss";
}

sub vcl_pass {
        set req.http.x-cache = "pass";
}

sub vcl_pipe {
        set req.http.x-cache = "pipe uncacheable";
}

sub vcl_synth {
        set req.http.x-cache = "synth synth";
}

sub vcl_deliver {
        if (obj.uncacheable) {
                set req.http.x-cache = req.http.x-cache + " uncacheable" ;
        } else {
                set req.http.x-cache = req.http.x-cache + " cached" ;
        }
        # uncomment the following line to show the information in the response
        set resp.http.x-cache = req.http.x-cache;
        set resp.http.x-condition=req.http.X-condition;
        unset resp.http.x-frame-options;
        unset resp.http.referrer-policy;
        unset resp.http.X-Varnish;
}