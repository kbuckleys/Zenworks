.pragma library
// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ONE RUN AT A TIME, EACH WITH ITS OWN JOB (audit 11-08). A Process told to
// stop still streams what it had, and its reader looked at properties
// already set for the next run — the last app's details on this one's page,
// the old picture's colors worn as the new one's. Here a job is
// { command, …whatever its reader needs }, and the reader looks at
// proc.job, which is set only as that run starts.
//
// The Process declares   property var job: null
//                        property var want: null    (latest)
//                        property var queue: []     (queued)
//                        onExited: RunJob.next(proc)
//
//   RunJob.latest(proc, job)  only the newest waiting job runs; one in
//                             flight is stopped for it (its stream, read
//                             against its own job, is dropped by the reader)
//   RunJob.queued(proc, job)  every job runs, in turn
//   RunJob.drop(proc)         nothing waiting, the run in flight stopped
//
// No imports: any library or document can take it.

function latest(proc, job) {
  proc.want = job;
  if (proc.running) proc.running = false;
  else next(proc);
}

function queued(proc, job) {
  proc.queue = proc.queue.concat([job]);
  if (!proc.running && !proc.job) next(proc);
}

function drop(proc) {
  if (proc.want !== undefined) proc.want = null;
  if (proc.queue !== undefined) proc.queue = [];
  proc.running = false;
}

// the next job, if any (from onExited; the stream has been read by then)
function next(proc) {
  let job = null;
  if (proc.want) { job = proc.want; proc.want = null; }
  else if (proc.queue !== undefined && proc.queue.length) { job = proc.queue[0]; proc.queue = proc.queue.slice(1); }
  proc.job = job;
  if (!job) return;
  proc.command = job.command;
  proc.running = true;
}

// whether the stream being read is the job wanted: not stopped for a newer one
function current(proc) {
  return !!proc.job && !proc.want;
}
