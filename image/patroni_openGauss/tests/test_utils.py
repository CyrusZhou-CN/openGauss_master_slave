import unittest

from mock import Mock, patch
from patroni.exceptions import PatroniException
from patroni.utils import Retry, RetryFailedError, enable_keepalive, find_executable, polling_loop, validate_directory


class TestUtils(unittest.TestCase):

    def test_polling_loop(self):
        self.assertEqual(list(polling_loop(0.001, interval=0.001)), [0])

    @patch('os.path.exists', Mock(return_value=True))
    @patch('os.path.isdir', Mock(return_value=True))
    @patch('tempfile.mkstemp', Mock(return_value=("", "")))
    @patch('os.remove', Mock(side_effect=Exception))
    def test_validate_directory_writable(self):
        self.assertRaises(Exception, validate_directory, "/tmp")

    @patch('os.path.exists', Mock(return_value=True))
    @patch('os.path.isdir', Mock(return_value=True))
    @patch('tempfile.mkstemp', Mock(side_effect=OSError))
    def test_validate_directory_not_writable(self):
        self.assertRaises(PatroniException, validate_directory, "/tmp")

    @patch('os.path.exists', Mock(return_value=False))
    @patch('os.makedirs', Mock(side_effect=OSError))
    def test_validate_directory_couldnt_create(self):
        self.assertRaises(PatroniException, validate_directory, "/tmp")

    @patch('os.path.exists', Mock(return_value=True))
    @patch('os.path.isdir', Mock(return_value=False))
    def test_validate_directory_is_not_a_directory(self):
        self.assertRaises(PatroniException, validate_directory, "/tmp")

    def test_enable_keepalive(self):
        with patch('socket.SIO_KEEPALIVE_VALS', 1, create=True):
            self.assertIsNotNone(enable_keepalive(Mock(), 10, 5))
        with patch('socket.SIO_KEEPALIVE_VALS', None, create=True):
            for platform in ('linux2', 'darwin', 'other'):
                with patch('sys.platform', platform):
                    self.assertIsNone(enable_keepalive(Mock(), 10, 5))

    @patch('sys.platform', 'win32')
    def test_find_executable(self):
        with patch('os.path.isfile', Mock(return_value=True)):
            self.assertEqual(find_executable('vim'), 'vim.exe')
        with patch('os.path.isfile', Mock(return_value=False)):
            self.assertIsNone(find_executable('vim'))
        with patch('os.path.isfile', Mock(side_effect=[False, True])):
            self.assertEqual(find_executable('vim', '/'), '/vim.exe')


@patch('time.sleep', Mock())
class TestRetrySleeper(unittest.TestCase):

    @staticmethod
    def _fail(times=1):
        scope = dict(times=0)

        def inner():
            if scope['times'] >= times:
                pass
            else:
                scope['times'] += 1
                raise PatroniException('Failed!')
        return inner

    def test_reset(self):
        retry = Retry(delay=0, max_tries=2)
        retry(self._fail())
        self.assertEqual(retry._attempts, 1)
        retry.reset()
        self.assertEqual(retry._attempts, 0)

    def test_too_many_tries(self):
        retry = Retry(delay=0)
        self.assertRaises(RetryFailedError, retry, self._fail(times=999))
        self.assertEqual(retry._attempts, 1)

    def test_maximum_delay(self):
        retry = Retry(delay=10, max_tries=100)
        retry(self._fail(times=10))
        self.assertTrue(retry._cur_delay < 4000, retry._cur_delay)
        # gevent's sleep function is picky about the type
        self.assertEqual(type(retry._cur_delay), float)

    def test_deadline(self):
        retry = Retry(deadline=0.0001)
        self.assertRaises(RetryFailedError, retry, self._fail(times=100))

    def test_copy(self):
        def _sleep(t):
            pass

        retry = Retry(sleep_func=_sleep)
        rcopy = retry.copy()
        self.assertTrue(rcopy.sleep_func is _sleep)
