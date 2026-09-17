%% wrapper for ExptServer.py

classdef ExptServer < handle
    properties
        server;
    end

    methods(Access = private)
        function self = ExptServer(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from ExptServer import ExptServer', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from ExptServer import ExptServer', pyglob);
            end
            self.server = py.eval('ExptServer(url)', pyglob);
            % Record the bound port only when we actually got the requested
            % one. A leftover / offline MATLAB that falls back to a random
            % port used to overwrite ExpConfigPortCache.txt and steal live
            % view from the generation publisher (s3329, s3284). Fallback
            % binds stay local until start_scan -- only a real scan rewrites
            % the rendezvous. Best-effort -- never let a cache-write problem
            % break the server.
            try
                actualUrl = char(self.server.get_url());
                tok = regexp(actualUrl, ':(\d+)$', 'tokens', 'once');
                reqTok = regexp(char(url), ':(\d+)$', 'tokens', 'once');
                if ~isempty(tok)
                    fellBack = ~isempty(reqTok) && ~strcmp(reqTok{1}, tok{1});
                    if fellBack
                        fprintf(['Using port: %s  (requested %s was busy -- fell back; ' ...
                            'NOT rewriting port cache so a leftover cannot steal live view)\n'], ...
                            tok{1}, reqTok{1});
                    else
                        self.writePortCache(tok{1});
                        fprintf('Using port: %s  (bound)\n', tok{1});
                    end
                end
            catch ME
                warning('ExptServer:portCacheWrite', 'could not record actual port: %s', ME.message);
            end
        end
        function writePortCache(self, portStr)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            cacheFile = fullfile(fileparts(path), 'ExpConfigPortCache.txt');
            fid = fopen(cacheFile, 'w');
            if fid ~= -1
                fprintf(fid, '%s', portStr);
                fclose(fid);
            end
        end
    end

    methods
        function res = check_request(self)
            % 0 - NoRequest
            % 1 - Pause
            % 2 - Abort
            res = double(self.server.check_request());
        end
        function res = start_scan(self)
            res = int64(self.server.start_scan());
            % This process is the live publisher now -- point the rendezvous
            % here even if the constructor fell back and refused to steal.
            try
                actualUrl = char(self.server.get_url());
                tok = regexp(actualUrl, ':(\d+)$', 'tokens', 'once');
                if ~isempty(tok)
                    self.writePortCache(tok{1});
                end
            catch
            end
        end
        function store_imgs(self, imgs, scan_id, seq_id)
%             disp('storing imgs');
            shape = size(imgs);
            if length(shape) == 2
                to_send = [double(shape(1)) double(shape(2)) double(1) imgs(:)'];
            elseif length(shape) == 3
                to_send = [double(shape(1)) double(shape(2)) double(shape(3)) imgs(:)'];
            end
            res = self.server.store_imgs(to_send, scan_id, seq_id);
        end
        function seq_cancel(self)
            self.server.seq_cancel();
        end
        function seq_finish(self)
            self.server.seq_finish();
        end
        function set_config(self, dateStamp, timeStamp)
            self.server.set_config(dateStamp, timeStamp)
        end
        function reset(self)
            self.server.reset();
        end
        function recreate_sock(self)
            self.server.recreate_sock();
        end
        function cleanup = register_cleanup(self)
            cleanup = FacyOnCleanup(@recreate_sock, self);
        end
    end

%     properties(Constant, Access=private)
    properties(Constant)
        cache = containers.Map();
    end
    methods(Static)
        function dropAll()
            remove(ExptServer.cache, keys(ExptServer.cache));
        end
        function res = get(url)
            cache = ExptServer.cache;
            % There is only ever one server per process (one image stream).
            % Reuse an existing valid one REGARDLESS of the requested url:
            % start_scan may rewrite the port cache after a bind-fallback, so
            % a later scan can arrive here with a different url. Keying
            % strictly on the url would then spawn a new server on a new
            % port every scan and orphan the port the live consumer is reading.
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            ks = keys(cache);
            for i = 1:numel(ks)
                existing = cache(ks{i});
                if ~isempty(existing) && isvalid(existing)
                    res = existing;
                    return;
                end
            end
            res = ExptServer(url);
            cache(url) = res;
        end
    end
end