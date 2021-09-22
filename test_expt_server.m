% script to test new communication between instances.

ES = ExptServer.get("tcp://127.0.0.1:8888");

scan_id = ES.start_seq(); % don't need to get scan_id from ES...
req = ES.check_request();
% 0 - NoRequest
% 1 - Pause
% 2 - Abort
seq_id = 1;

while req ~= 2
    if req == 1
        fprintf("Sequence paused\n");
        pause(0.5) % check every 0.5 seconds'
        req = ES.check_request();
        continue
    else
        fprintf("Running sequence %i\n", seq_id);
        pause(0.25) % sequence running
        imgs = rand(110, 50, 2);
        ES.store_imgs(imgs, scan_id, seq_id);
        pause(0.1) % sequence running
        imgs = rand(110, 50, 2);
        ES.store_imgs(imgs, scan_id, seq_id);
        ES.seq_finish();
        seq_id = seq_id + 1;
        req = ES.check_request();
    end
end

disp("Sequence aborted");