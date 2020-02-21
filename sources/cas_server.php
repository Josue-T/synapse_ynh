<?php

$base_url = "/_matrix/cas_server.php";

$url = explode('?', $_SERVER['REQUEST_URI'], 2)[0];

switch ($url) {
    case $base_url . "/proxyValidate":
        session_id($_GET['ticket']);
        session_start();

        if ($_SESSION['user_authenticated']) {
            ?>
                <cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
                    <cas:authenticationSuccess>
                    <cas:user><?php echo $_SESSION['user']; ?></cas:user>
                    <cas:proxyGrantingTicket>PGTIOU-84678-8a9d...</cas:proxyGrantingTicket>
                    </cas:authenticationSuccess>
                </cas:serviceResponse>
            <?php
        } else {
            ?>
                <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
                    <cas:authenticationFailure code="INVALID_TICKET">
                        ticket PT-1856376-1HMgO86Z2ZKeByc5XdYD not recognized
                    </cas:authenticationFailure>
                </cas:serviceResponse>
            <?php
        }
    break;

    case $base_url . "/login":
        $ticket = bin2hex(random_bytes(50));
        session_id($ticket);
        session_start();

        if (array_key_exists('REMOTE_USER', $_SERVER) && strlen($_SERVER['REMOTE_USER']) > 0) {
            $_SESSION['user_authenticated'] = true;
            $_SESSION['user'] = $_SERVER['REMOTE_USER'];

            header('Status: 302 Moved Temporarily', false, 302);
            header('Location: ' . $_GET['service'] . '&ticket=' . $ticket);
        } else {
            echo "Authentication Fail.";
        }
        session_commit();
    break;

    case $base_url:

        header('Status: 302 Moved Temporarily', false, 302);
        header('Location: ' . $_GET['redirectUrl']);

    break;

    default:
        echo "Bad URL";
}
?>
